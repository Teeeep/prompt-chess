require 'vcr'

VCR.configure do |c|
  c.cassette_library_dir = 'spec/vcr_cassettes'
  c.hook_into :webmock
  c.configure_rspec_metadata!

  # Filter actual API keys from ENV
  c.filter_sensitive_data('<OPENAI_API_KEY>') { ENV['OPENAI_API_KEY'] }
  c.filter_sensitive_data('<ANTHROPIC_API_KEY>') { ENV['ANTHROPIC_API_KEY'] }

  # Filter all Anthropic API keys (including test keys) by pattern
  c.before_record do |interaction|
    api_key_header = interaction.request.headers['X-Api-Key']&.first
    if api_key_header&.start_with?('sk-ant-')
      interaction.request.headers['X-Api-Key'] = ['<ANTHROPIC_API_KEY>']
    end

    # Filter OpenAI keys from Authorization header
    auth_header = interaction.request.headers['Authorization']&.first
    if auth_header&.include?('Bearer sk-')
      interaction.request.headers['Authorization'] = ['Bearer <OPENAI_API_KEY>']
    end
  end

  c.allow_http_connections_when_no_cassette = false

  # Ignore localhost connections for Selenium/Capybara system tests
  c.ignore_hosts '127.0.0.1', 'localhost'
end
