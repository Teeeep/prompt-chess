# Helper to ensure Stockfish processes are cleaned up after tests
# This prevents zombie processes when tests fail or are interrupted

RSpec.configure do |config|
  config.around(:each, :stockfish) do |example|
    stockfish_services = []

    # Track all StockfishService instances created during the test
    original_new = StockfishService.method(:new)

    allow(StockfishService).to receive(:new) do |*args, **kwargs|
      service = original_new.call(*args, **kwargs)
      stockfish_services << service
      service
    end

    # Run the test
    example.run

    # Cleanup all services, even if test failed
    stockfish_services.each do |service|
      begin
        service.close
      rescue => e
        # Ignore errors during cleanup
        Rails.logger.debug("Error closing Stockfish service in test cleanup: #{e.message}")
      end
    end
  end
end
