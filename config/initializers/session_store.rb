# Be sure to restart your server when you modify this file.

Rails.application.config.session_store :cookie_store,
  key: "_prompt_chess_session",
  secure: Rails.env.production?,  # HTTPS only in production
  httponly: true,                  # Not accessible via JavaScript
  same_site: :lax                  # CSRF protection
