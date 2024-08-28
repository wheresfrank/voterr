class SessionsController < ApplicationController
  before_action :require_login, except: :join
  
  def index
    @sessions = current_user.sessions
  end
  
  def new
    @session = current_user.sessions.new
  end
  
  def create
    @session = current_user.sessions.new(session_params)
    
    if @session.save
      redirect_to session_path(@session), notice: 'Session created!'
    else
      render :new, alert: 'Session could not be created.'
    end
  end
  
  def show
    @session = Session.find_by(id: params[:id])
    @movies = fetch_random_movies(current_user)
  end

  def join
    @session = Session.find_by(session_token: params[:id])
    if @session
      render :show
    else
      redirect_to root_path, alert: 'Invalid session link'
    end
  end

  private

  def session_params
    params.require(:session).permit(:session_token, :session_name, :winner_id, :winner_type)
  end

  def fetch_plex_server_info(user)
    connection = Faraday.new(url: 'https://plex.tv', request: { timeout: 10, open_timeout: 5 }) do |faraday|
      faraday.request :url_encoded
      faraday.adapter Faraday.default_adapter
    end
  
    response = connection.get('/api/v2/resources') do |req|
      req.headers['Accept'] = 'application/json'
      req.headers['X-Plex-Token'] = user.plex_token
      req.headers['X-Plex-Client-Identifier'] = user.plex_client_id
    end
  
    if response.status == 200
      servers = JSON.parse(response.body)
  
      # Find the first available server that provides 'server' capabilities
      server = servers.find { |s| s['provides'].include?('server') }
  
      if server
        connection_info = select_public_connection(server['connections'])
        if connection_info
          {
            ip: connection_info['address'],
            port: connection_info['port'],
            local: connection_info['local']
          }
        else
          Rails.logger.error("No suitable public connection found for Plex server")
          nil
        end
      else
        Rails.logger.error("No Plex servers found for user")
        nil
      end
    else
      Rails.logger.error("Failed to fetch Plex server info: #{response.body}")
      nil
    end
  end
  
  def select_public_connection(connections)
    # Prefer non-local (public) connections that are not relayed
    public_connection = connections.find { |conn| !conn['local'] && !conn['relay'] }
    return public_connection if public_connection
  
    # As a fallback, use a relayed connection (if available)
    connections.find { |conn| !conn['local'] && conn['relay'] }
  end

  def fetch_sections(user)
    server_info = fetch_plex_server_info(user)

    if server_info
      connection = Faraday.new(url: "http://#{server_info[:ip]}:#{server_info[:port]}") do |faraday|
        faraday.request :url_encoded
        faraday.adapter Faraday.default_adapter
      end

      response = connection.get('/library/sections') do |req|
        req.headers['Accept'] = 'application/xml'
        req.headers['X-Plex-Token'] = user.plex_token
        req.headers['X-Plex-Client-Identifier'] = user.plex_client_id
      end

      if response.status == 200
        xml_doc = Nokogiri::XML(response.body)
        sections = xml_doc.xpath('//Directory').map do |directory|
          {
            title: directory.attr('title'),
            section_id: directory.attr('key')
          }
        end
        sections
      else
        Rails.logger.error("Failed to fetch sections: #{response.body}")
        []
      end
    else
      Rails.logger.error("No Plex server info available")
      []
    end
  end

  def extract_genres(video)
    genres = video.xpath('Genre').map do |genre|
      genre.attr('tag')
    end
    genres
  end

  def fetch_random_movies(user)
    sections = fetch_sections(user)
    section_id = sections.first[:section_id]
    server_info = fetch_plex_server_info(user)

    connection = Faraday.new(url: "http://#{server_info[:ip]}:#{server_info[:port]}") do |faraday|
      faraday.request :url_encoded
      faraday.adapter Faraday.default_adapter
    end

    response = connection.get("/library/sections/#{section_id}/all") do |req|
      req.headers['Accept'] = 'application/xml'
      req.headers['X-Plex-Token'] = user.plex_token
      req.headers['X-Plex-Client-Identifier'] = user.plex_client_id
    end

    xml_doc = Nokogiri::XML(response.body)

    movies = xml_doc.xpath('//Video').map do |video|
      {
        title: video.attr('title'),
        poster_url: "http://#{server_info[:ip]}:#{server_info[:port]}#{video.attr('thumb')}?X-Plex-Token=#{user.plex_token}",
        plex_id: video.attr('ratingKey'),
        genres: extract_genres(video),
        tagline: video.attr('tagline'),
        summary: video.attr('summary'),
        content_rating: video.attr('contentRating'),
        audience_rating: video.attr('audienceRating'),
        rating: video.attr('rating')
      }
    end

    movies.sample(2)
  end
end