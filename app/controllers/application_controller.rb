class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  # Disabled for MVP - API-only application doesn't need browser detection
  # allow_browser versions: :modern
end
