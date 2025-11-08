# Stockfish engine configuration
STOCKFISH_PATH = ENV.fetch("STOCKFISH_PATH") do
  # Try common paths
  paths = [
    "/opt/homebrew/bin/stockfish",  # Homebrew on Apple Silicon
    "/usr/local/bin/stockfish",     # Homebrew on Intel Mac
    "/usr/bin/stockfish",            # Linux package manager
    "stockfish"                      # In PATH
  ]

  paths.find { |path| File.exist?(path) || system("which #{path} > /dev/null 2>&1") } || "stockfish"
end
