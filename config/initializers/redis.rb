require 'redis'

if Rails.env.production?
  Redis.current = Redis.new(
    url: ENV.fetch("REDIS_URL"),
    ssl_params: { 
      verify_mode: OpenSSL::SSL::VERIFY_NONE
    }
  )
end 