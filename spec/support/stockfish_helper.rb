# Helper to ensure Stockfish processes are cleaned up after tests
# This prevents zombie processes when tests fail or are interrupted

module StockfishTestHelper
  # Track all StockfishService instances created during tests
  @stockfish_services = []

  def self.register_service(service)
    @stockfish_services ||= []
    @stockfish_services << service
  end

  def self.cleanup_all
    @stockfish_services ||= []
    @stockfish_services.each do |service|
      begin
        service.close
      rescue => e
        # Ignore errors during cleanup
      end
    end
    @stockfish_services.clear
  end
end

# Monkey-patch StockfishService to register instances
class StockfishService
  alias_method :original_initialize, :initialize

  def initialize(*args, **kwargs)
    original_initialize(*args, **kwargs)
    StockfishTestHelper.register_service(self) if defined?(RSpec)
  end
end

RSpec.configure do |config|
  config.after(:each, :stockfish) do
    StockfishTestHelper.cleanup_all
  end
end
