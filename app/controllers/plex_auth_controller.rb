class PlexAuthController < ApplicationController
  PLEX_BASE_URL = 'https://plex.tv'.freeze
  PLEX_PRODUCT = 'Voterr'.freeze
  PLEX_VERSION = '1.0'.freeze
  VOTERR_CLIENT_ID = ENV['VOTERR_CLIENT_ID'] || 'voterr-8a7b6c5d-4e3f-2g1h-9i8j-7k6l5m4n3o2p'

  def new
    begin
      pin = generate_plex_pin
      session[:plex_pin_id] = pin['id']
      @auth_url = construct_auth_url(pin['code'])
    rescue => e
      Rails.logger.error("Error initiating Plex auth: #{e.message}")
      redirect_to root_path, alert: "Unable to initiate Plex authentication. Please try again later."
    end
  end

  def callback
    pin_id = session[:plex_pin_id]
    auth_token = check_pin_status(pin_id)

    if auth_token
      user_data = fetch_plex_user_data(auth_token)
      if user_data
        user = User.find_or_initialize_by(email: user_data[:email])
        user.update!(
          plex_token: auth_token,
          name: user_data[:username]
        )
        session[:user_id] = user.id
        redirect_to root_path, notice: 'Successfully authenticated with Plex!'
      else
        redirect_to root_path, alert: 'Failed to fetch user data from Plex.'
      end
    else
      redirect_to root_path, alert: 'Failed to authenticate with Plex. Please try again.'
    end
  end

  private

  def plex_headers
    {
      'Accept' => 'application/json',
      'X-Plex-Product' => PLEX_PRODUCT,
      'X-Plex-Version' => PLEX_VERSION,
      'X-Plex-Client-Identifier' => VOTERR_CLIENT_ID
    }
  end

  def generate_plex_pin
    response = plex_request(:post, '/api/v2/pins', params: { strong: true })
    if response.status == 200 || response.status == 201
      JSON.parse(response.body)
    else
      raise "Failed to generate Plex PIN. Status: #{response.status}"
    end
  end

  def construct_auth_url(pin_code)
    params = {
      clientID: VOTERR_CLIENT_ID,
      code: pin_code,
      context: {
        device: {
          product: PLEX_PRODUCT
        }
      },
      forwardUrl: callback_plex_auth_url
    }
    
    "https://app.plex.tv/auth#?#{params.to_query}"
  end

  def check_pin_status(pin_id)
    response = plex_request(:get, "/api/v2/pins/#{pin_id}")
    if response.status == 200
      data = JSON.parse(response.body)
      data['authToken']
    end
  end

  def fetch_plex_user_data(auth_token)
    response = plex_request(:get, '/api/v2/user', auth_token: auth_token)
    if response.status == 200
      data = JSON.parse(response.body)
      {
        email: data['email'],
        username: data['username']
      }
    end
  end

  def plex_request(method, endpoint, auth_token: nil, params: {})
    url = "#{PLEX_BASE_URL}#{endpoint}"
    response = Faraday.send(method, url) do |req|
      req.headers.merge!(plex_headers)
      req.headers['X-Plex-Token'] = auth_token if auth_token
      req.params.merge!(params)
    end

    Rails.logger.info("Plex API Request: #{method.upcase} #{url}")
    Rails.logger.info("Plex API Response Status: #{response.status}")
    Rails.logger.debug("Plex API Response Body: #{response.body}")

    response
  end
end