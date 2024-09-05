class PlexAuthController < ApplicationController
  require "browser"

  PLEX_BASE_URL = 'https://plex.tv'.freeze
  PLEX_PRODUCT = 'Voterr'.freeze
  PLEX_VERSION = 'Plex OAuth'.freeze
  VOTERR_CLIENT_ID = 'voterr-8a7b6c5d-4e3f-2g1h-9i8j-7k6l5m4n3o2p'

  def new
    @plex_product = "Voterr"
    @plex_version = "1.0"
    @client_id = VOTERR_CLIENT_ID
    @browser_name = browser.name
    @browser_version = browser.version
    @device = browser.platform.name
    @device_name = "#{browser.name} (Voterr)"
    @callback_url = callback_plex_auth_url
  end

  def callback
    auth_token = params.dig(:plex_auth, :auth_token)
    
    if auth_token
      user_data = fetch_plex_user_data(auth_token)
      if user_data
        user = User.find_or_initialize_by(email: user_data[:email])
        user.update!(
          plex_token: auth_token,
          name: user_data[:username]
        )
        FetchAndStoreMoviesJob.perform_later(user)
        session[:user_id] = user.id
        render json: { success: true, message: 'Successfully authenticated with Plex!' }
      else
        render json: { success: false, message: 'Failed to fetch user data from Plex.' }, status: :unprocessable_entity
      end
    else
      render json: { success: false, message: 'No auth token provided.' }, status: :bad_request
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

    response
  end
end