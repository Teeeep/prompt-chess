require 'vcr'

VCR.configure do |c|
  c.cassette_library_dir = 'spec/vcr_cassettes'
  c.hook_into :webmock
  c.configure_rspec_metadata!

  # Filter actual API keys from ENV (only if set)
  c.filter_sensitive_data('<OPENAI_API_KEY>') { ENV['OPENAI_API_KEY'] } if ENV['OPENAI_API_KEY']
  c.filter_sensitive_data('<ANTHROPIC_API_KEY>') { ENV['ANTHROPIC_API_KEY'] } if ENV['ANTHROPIC_API_KEY']

  c.allow_http_connections_when_no_cassette = false

  # Allow cassettes to be reused for multiple identical requests
  c.default_cassette_options = { allow_playback_repeats: true }

  # Ignore localhost connections for Selenium/Capybara system tests
  c.ignore_hosts '127.0.0.1', 'localhost'
end
