require 'redis'

redis_url = ENV['REDIS_URL']

if redis_url
  # Parse the URL
  uri = URI.parse(redis_url)
  
  # Configure Redis with SSL verification disabled
  Redis.current = Redis.new(
    url: redis_url,
    ssl_params: {
      verify_mode: OpenSSL::SSL::VERIFY_NONE
    }
  )
end 