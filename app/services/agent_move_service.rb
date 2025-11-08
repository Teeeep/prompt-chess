class AgentMoveService
  class InvalidMoveError < StandardError; end
  class LlmApiError < StandardError; end
  class ConfigurationError < StandardError; end

  MAX_RETRIES = 3

  def initialize(agent:, validator:, move_history:, session:)
    raise ArgumentError, "agent is required" unless agent
    raise ArgumentError, "validator is required" unless validator

    @agent = agent
    @validator = validator
    @move_history = move_history
    @session = session

    # Validate LLM configuration
    unless LlmConfigService.configured?(@session)
      raise ConfigurationError, "LLM not configured in session"
    end
  end

  # Generate the agent's next move
  # Returns: {
  #   move: "e4",
  #   prompt: "...",
  #   response: "...",
  #   tokens: 150,          # Total tokens across all retry attempts
  #   time_ms: 500,         # Total time from first to last attempt
  #   retry_count: 0        # Number of retries (0 if succeeded on first try)
  # }
  def generate_move
    retries = 0
    all_prompts = []
    all_responses = []
    total_tokens = 0
    start_time = Time.now

    loop do
      prompt = build_prompt(retry_attempt: retries)
      all_prompts << prompt

      begin
        # Call LLM
        anthropic = AnthropicClient.new(session: @session)
        llm_response = anthropic.complete(prompt: prompt)
        all_responses << llm_response[:content]

        # Accumulate tokens across all attempts
        total_tokens += llm_response[:usage][:total_tokens]

        # Parse move from response
        move = parse_move_from_response(llm_response[:content])

        # Check if move is valid
        if move && @validator.valid_move?(move)
          time_ms = ((Time.now - start_time) * 1000).to_i

          return {
            move: move,
            prompt: all_prompts.join("\n---RETRY---\n"),
            response: all_responses.join("\n---RETRY---\n"),
            tokens: total_tokens,
            time_ms: time_ms,
            retry_count: retries
          }
        end

        # Increment retry counter
        retries += 1

        # Give up after max retries
        if retries >= MAX_RETRIES
          error_msg = if move
            "Invalid move suggested: #{move}. Failed to produce valid move after #{MAX_RETRIES} attempts."
          else
            "Could not parse move from response. Failed after #{MAX_RETRIES} attempts."
          end

          raise InvalidMoveError, error_msg
        end
      rescue Faraday::TimeoutError => e
        raise LlmApiError, "Failed to get response from LLM (timeout): #{e.message}"
      rescue Faraday::Error => e
        raise LlmApiError, "Failed to get response from LLM: #{e.message}"
      end

      # Continue loop to retry
    end
  end

  private

  def build_prompt(retry_attempt: 0)
    base_prompt = <<~PROMPT
      You are a chess-playing AI agent named "#{@agent.name}".

      Your personality and strategy: #{@agent.prompt_text}

      Current Position (FEN): #{@validator.current_fen}

      #{format_move_history}

      Game Context:
      - Your color: White
      - Move number: #{next_move_number}
      - Legal moves: #{@validator.legal_moves.join(', ')}
    PROMPT

    if retry_attempt > 0
      base_prompt += <<~RETRY

        IMPORTANT: Your previous response was invalid. Please respond EXACTLY in this format:
        MOVE: [choose ONE move from the legal moves list above]

        Example: MOVE: e4
      RETRY
    else
      base_prompt += <<~NORMAL

        Analyze the position and respond with your next move.
        Format: MOVE: [your move in standard algebraic notation]

        Example responses:
        - "I'll control the center with e4. MOVE: e4"
        - "Developing the knight is best. MOVE: Nf3"

        Now choose your move:
      NORMAL
    end

    base_prompt
  end

  def format_move_history
    return "Move History: (game start)" if @move_history.empty?

    lines = [ "Move History:" ]
    @move_history.each_slice(2).with_index(1) do |pair, number|
      white_move = pair[0]
      black_move = pair[1]

      if black_move
        lines << "#{number}. #{white_move.move_notation} #{black_move.move_notation}"
      else
        lines << "#{number}. #{white_move.move_notation}"
      end
    end

    lines.join("\n")
  end

  def next_move_number
    (@move_history.length / 2) + 1
  end

  def parse_move_from_response(response)
    # Look for pattern: MOVE: <move>
    # Case insensitive, capture the move
    if response =~ /move:\s*(\S+)/i
      return $1.strip
    end

    nil
  end
end
