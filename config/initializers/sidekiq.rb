require 'sidekiq'

Sidekiq.configure_server do |config|
    config.redis = { ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE } }
end