# Disable host authorization in test environment
# This allows RSpec request specs to work without "Blocked host" errors
if Rails.env.test?
  Rails.application.config.hosts.clear
end
