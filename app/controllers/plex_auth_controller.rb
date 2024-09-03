class PlexAuthController < ApplicationController
  PLEX_BASE_URL = 'https://plex.tv'.freeze
  PLEX_PRODUCT = 'Voterr'.freeze
  PLEX_VERSION = '1.0'.freeze
  VOTERR_CLIENT_ID = 'voterr-8a7b6c5d-4e3f-2g1h-9i8j-7k6l5m4n3o2p'

  def new
    begin
      @pin = generate_plex_pin
      @auth_url = plex_auth_url(@pin['code'])
      session[:plex_pin_id] = @pin['id']
    rescue => e
      Rails.logger.error("Error in PlexAuthController#new: #{e.message}")
      redirect_to root_path, alert: "Unable to initiate Plex authentication. Please try again later."
    end
  end

  def callback
    pin_id = session[:plex_pin_id]
    auth_token = check_pin_status(pin_id)

    if auth_token
      user_data = fetch_plex_user_data(auth_token)
      server_id = fetch_plex_server_id(auth_token)

      if user_data && server_id
        user = User.find_or_initialize_by(email: user_data[:email])
        user.update!(
          plex_token: auth_token,
          plex_client_id: VOTERR_CLIENT_ID,
          plex_server_id: server_id,
          name: user_data[:username]
        )

        session[:user_id] = user.id
        FetchAndStoreMoviesJob.perform_later(user)
        redirect_to root_path, notice: 'Successfully authenticated with Plex!'
      else
        redirect_to root_path, alert: 'Failed to fetch user data or server information from Plex.'
      end
    else
      redirect_to root_path, alert: 'Failed to authenticate with Plex. Please try again.'
    end
  end

  private

  def plex_connection
    Faraday.new(url: PLEX_BASE_URL) do |faraday|
      faraday.request :url_encoded
      faraday.adapter Faraday.default_adapter
    end
  end

  def plex_headers
    {
      'Accept' => 'application/json',
      'X-Plex-Product' => PLEX_PRODUCT,
      'X-Plex-Version' => PLEX_VERSION,
      'X-Plex-Client-Identifier' => VOTERR_CLIENT_ID,
      'X-Plex-Platform' => 'Web',
      'X-Plex-Platform-Version' => PLEX_VERSION,
      'X-Plex-Device' => 'Browser',
      'X-Plex-Device-Name' => 'Voterr Web App',
      'X-Plex-Model' => 'Voterr',
      'X-Plex-Sync-Version' => '2',
      'X-Plex-Features' => 'external-media,indirect-media',
      'X-Plex-Language' => 'en'
    }
  end

  def generate_plex_pin
    max_retries = 3
    retries = 0

    loop do
      response = plex_request(:post, '/api/v2/pins', nil, strong: 'true')
      
      case response.status
      when 200, 201
        data = JSON.parse(response.body)
        return {
          'id' => data['id'],
          'code' => data['code']
        }
      when 429
        retries += 1
        if retries < max_retries
          wait_time = 2 ** retries  # Exponential backoff
          Rails.logger.warn("Plex API rate limit exceeded. Waiting #{wait_time} seconds before retry #{retries}/#{max_retries}.")
          sleep(wait_time)
        else
          Rails.logger.error("Max retries reached for Plex pin generation.")
          raise "Failed to generate Plex pin: Rate limit exceeded after #{max_retries} retries."
        end
      else
        Rails.logger.error("Failed to generate Plex pin. Response: #{response.body}")
        raise "Failed to generate Plex pin. Status: #{response.status}"
      end
    end
  rescue JSON::ParserError => e
    Rails.logger.error("Error parsing JSON in generate_plex_pin: #{e.message}")
    raise "Error generating Plex pin: Invalid JSON response"
  rescue => e
    Rails.logger.error("Error in generate_plex_pin: #{e.message}")
    raise "Error generating Plex pin: #{e.message}"
  end

  def plex_auth_url(pin_code)
    base_url = "https://app.plex.tv/auth#"
    params = {
      'clientID' => VOTERR_CLIENT_ID,
      'code' => pin_code,
      'context[device][product]' => PLEX_PRODUCT,
      'context[device][version]' => PLEX_VERSION,
      'context[device][platform]' => 'Web',
      'context[device][platformVersion]' => PLEX_VERSION,
      'context[device][device]' => 'Browser',
      'context[device][deviceName]' => 'Voterr Web App',
      'context[device][model]' => 'Voterr',
      'context[device][screenResolution]' => '1920x1080',
      'context[device][layout]' => 'desktop',
      'context[device][language]' => 'en',
      'forwardUrl' => callback_plex_auth_url
    }
    
    "#{base_url}?#{params.to_query}"
  end

  def check_pin_status(pin_id)
    response = plex_request(:get, "/api/v2/pins/#{pin_id}")
    if response.status == 200
      data = JSON.parse(response.body)
      auth_token = data['authToken']
      auth_token if auth_token.present?
    else
      Rails.logger.error("Failed to check pin status. Response: #{response.body}")
      nil
    end
  rescue JSON::ParserError => e
    Rails.logger.error("Error parsing JSON in check_pin_status: #{e.message}")
    nil
  end

  def fetch_plex_user_data(auth_token)
    response = plex_request(:get, '/api/v2/user', auth_token)
    if response.status == 200
      data = JSON.parse(response.body)
      {
        email: data['email'],
        username: data['username']
      }
    else
      Rails.logger.error("Failed to fetch user data. Response: #{response.body}")
      nil
    end
  rescue JSON::ParserError => e
    Rails.logger.error("Error parsing JSON in fetch_plex_user_data: #{e.message}")
    nil
  end

  def fetch_plex_server_id(auth_token)
    response = plex_request(:get, '/api/v2/resources', auth_token)
    if response.status == 200
      servers = JSON.parse(response.body)
      server = servers.find { |s| s['provides'].include?('server') }
      server&.dig('clientIdentifier')
    else
      Rails.logger.error("Failed to fetch server ID. Response: #{response.body}")
      nil
    end
  rescue JSON::ParserError => e
    Rails.logger.error("Error parsing JSON in fetch_plex_server_id: #{e.message}")
    nil
  end

  def plex_request(method, endpoint, auth_token = nil, params = {})
    response = plex_connection.send(method, endpoint) do |req|
      req.headers.merge!(plex_headers)
      req.headers['X-Plex-Token'] = auth_token if auth_token
      req.headers['Content-Type'] = 'application/json'
      req.params.merge!(params)
    end
    
    Rails.logger.info("Plex API Request: #{method.upcase} #{endpoint}")
    Rails.logger.info("Plex API Response Status: #{response.status}")
    Rails.logger.debug("Plex API Response Body: #{response.body}")
    
    response
  end
end