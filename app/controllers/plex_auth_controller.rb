class PlexAuthController < ApplicationController
  def new
    @client_id = SecureRandom.uuid
    @pin = generate_plex_pin(@client_id)
    @auth_url = plex_auth_url(@client_id, @pin['code'])
    session[:plex_client_id] = @client_id
    session[:plex_pin_id] = @pin['id']
    redirect_to @auth_url, allow_other_host: true
  end

  def callback
    client_id = session[:plex_client_id]
    pin_id = session[:plex_pin_id]
    auth_token = check_pin_status(pin_id, client_id)
  
    if auth_token
      user = User.find_or_create_by(plex_client_id: client_id) do |u|
        u.plex_token = auth_token
        u.email = extract_email_from_plex(auth_token)
      end
      session[:user_id] = user.id
      redirect_to root_path, notice: 'Successfully authenticated with Plex!'
    else
      redirect_to root_path, alert: 'Failed to authenticate with Plex.'
    end
  end

  private

  def generate_plex_pin(client_id)
    connection = Faraday.new(url: 'https://plex.tv') do |faraday|
      faraday.request :url_encoded
      faraday.adapter Faraday.default_adapter
    end
  
    response = connection.post('/api/v2/pins') do |req|
      req.headers['Accept'] = 'application/xml'
      req.params['strong'] = 'true'
      req.params['X-Plex-Client-Identifier'] = client_id
      req.params['X-Plex-Product'] = 'Voterr'
    end
  
    xml_doc = Nokogiri::XML(response.body)
    pin_id = xml_doc.at_xpath('//pin/@id').value
    pin_code = xml_doc.at_xpath('//pin/@code').value
    {
      'id' => pin_id,
      'code' => pin_code
    }
  end

  def plex_auth_url(client_id, pin_code)
    'https://app.plex.tv/auth#?' + {
      clientID: client_id,
      code: pin_code,
      forwardUrl: callback_plex_auth_url
    }.to_query
  end

  def check_pin_status(pin_id, client_id)
    connection = Faraday.new(url: 'https://plex.tv') do |faraday|
      faraday.request :url_encoded
      faraday.adapter Faraday.default_adapter
    end
  
    response = connection.get("/api/v2/pins/#{pin_id}") do |req|
      req.headers['Accept'] = 'application/xml'  # Request XML format since JSON is not supported
      req.params['X-Plex-Client-Identifier'] = client_id
    end
  
    xml_doc = Nokogiri::XML(response.body)
    auth_token = xml_doc.at_xpath('//pin/@authToken').value
  
    # Return the auth token or nil if it's not present
    auth_token.present? ? auth_token : nil
  end

  def extract_email_from_plex(auth_token)
    connection = Faraday.new(url: 'https://plex.tv') do |faraday|
      faraday.request :url_encoded
      faraday.adapter Faraday.default_adapter
    end
  
    response = connection.get('/api/v2/user') do |req|
      req.headers['Accept'] = 'application/xml' # Plex may return XML, so we parse it accordingly
      req.headers['X-Plex-Token'] = auth_token
    end
  
    xml_doc = Nokogiri::XML(response.body)
    email = xml_doc.at_xpath('//user/@email').value
  
    email
  end
end