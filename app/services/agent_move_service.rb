class AgentMoveService
  class InvalidMoveError < StandardError; end

  def initialize(agent:, validator:, move_history:, session:)
    raise ArgumentError, "agent is required" unless agent
    raise ArgumentError, "validator is required" unless validator

    @agent = agent
    @validator = validator
    @move_history = move_history
    @session = session
  end

  # Generate the agent's next move
  # Returns: {
  #   move: "e4",
  #   prompt: "...",
  #   response: "...",
  #   tokens: 150,
  #   time_ms: 500
  # }
  def generate_move
    prompt = build_prompt
    start_time = Time.now

    # Call LLM
    anthropic = AnthropicClient.new(session: @session)
    llm_response = anthropic.complete(prompt: prompt)

    time_ms = ((Time.now - start_time) * 1000).to_i

    # Parse move from response
    move = parse_move_from_response(llm_response[:content])

    unless move
      raise InvalidMoveError, "Could not parse move from response: #{llm_response[:content]}"
    end

    # Validate move
    unless @validator.valid_move?(move)
      raise InvalidMoveError, "Invalid move suggested: #{move}"
    end

    {
      move: move,
      prompt: prompt,
      response: llm_response[:content],
      tokens: llm_response[:usage][:total_tokens],
      time_ms: time_ms
    }
  end

  private

  def build_prompt(retry_attempt: 0)
    <<~PROMPT
      You are a chess-playing AI agent named "#{@agent.name}".

      Your personality and strategy: #{@agent.prompt_text}

      Current Position (FEN): #{@validator.current_fen}

      #{format_move_history}

      Game Context:
      - Your color: White
      - Move number: #{next_move_number}
      - Legal moves: #{@validator.legal_moves.join(', ')}

      Analyze the position and respond with your next move.
      Format: MOVE: [your move in standard algebraic notation]

      Example responses:
      - "I'll control the center with e4. MOVE: e4"
      - "Developing the knight is best. MOVE: Nf3"

      Now choose your move:
    PROMPT
  end

  def format_move_history
    return "Move History: (game start)" if @move_history.empty?

    lines = ["Move History:"]
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
