class FetchAndStoreMoviesJob < ApplicationJob
  queue_as :default

  class NoAvailableServersError < StandardError; end

  def perform(user)
    Rails.logger.info("Starting FetchAndStoreMoviesJob for user #{user.id}")
    begin
      libraries = fetch_accessible_libraries(user)
      
      if libraries.empty?
        raise NoAvailableServersError, "No available movie libraries found"
      end

      Rails.logger.info("Found #{libraries.length} movie libraries")

      libraries.each do |library|
        fetch_movies_from_library(user, library)
      end

    rescue NoAvailableServersError => e
      Rails.logger.error("No available movie libraries found for user #{user.id}: #{e.message}")
      # Handle the error (e.g., update a status in the database)
    rescue StandardError => e
      Rails.logger.error("Error occurred while fetching and storing movies for user #{user.id}: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      # Handle the error
    end
  end

  private

  def fetch_accessible_libraries(user)
    Rails.logger.info("Fetching accessible libraries for user #{user.id}")
    connection = Faraday.new(url: 'https://plex.tv', request: { timeout: 30, open_timeout: 10 }) do |faraday|
      faraday.request :url_encoded
      faraday.adapter Faraday.default_adapter
    end

    response = connection.get('/api/v2/resources') do |req|
      req.headers['Accept'] = 'application/json'
      req.headers['X-Plex-Token'] = user.plex_token
      req.headers['X-Plex-Client-Identifier'] = user.plex_client_id
    end

    Rails.logger.info("Response status from /api/v2/resources: #{response.status}")

    if response.status == 200
      resources = JSON.parse(response.body)
      servers = resources.select { |r| r['provides'] == 'server' }
      Rails.logger.info("Found #{servers.length} servers")

      if servers.any?
        first_server = servers.first
        user.update(plex_server_id: first_server['clientIdentifier'])
      end

      libraries = []
      servers.each do |server|
        server_libraries = fetch_server_libraries(user, server)
        libraries.concat(server_libraries)
      end

      Rails.logger.info("Total movie libraries found: #{libraries.length}")
      libraries
    else
      Rails.logger.error("Failed to fetch resources: #{response.body}")
      []
    end
  end

  def fetch_server_libraries(user, server)
    Rails.logger.info("Fetching libraries for server: #{server['name']}")
    
    connection_uri = select_best_connection(server['connections'])
    return [] unless connection_uri

    connection = Faraday.new(url: connection_uri, request: { timeout: 30, open_timeout: 10 }) do |faraday|
      faraday.request :url_encoded
      faraday.adapter Faraday.default_adapter
    end

    begin
      response = connection.get('/library/sections') do |req|
        req.headers['Accept'] = 'application/json'
        req.headers['X-Plex-Token'] = server['accessToken']
        req.headers['X-Plex-Client-Identifier'] = user.plex_client_id
      end

      Rails.logger.info("Response status from /library/sections: #{response.status}")

      if response.status == 200
        sections = JSON.parse(response.body)['MediaContainer']['Directory']
        movie_libraries = sections.select { |section| section['type'] == 'movie' }
        Rails.logger.info("Found #{movie_libraries.length} movie libraries for server #{server['name']}")

        movie_libraries.map do |section|
          {
            title: section['title'],
            section_id: section['key'],
            server_id: server['clientIdentifier'],
            uri: connection_uri,
            access_token: server['accessToken']
          }
        end
      else
        Rails.logger.error("Failed to fetch libraries for server #{server['name']}: #{response.body}")
        []
      end
    rescue Faraday::ConnectionFailed => e
      Rails.logger.error("Connection failed for server #{server['name']}: #{e.message}")
      []
    rescue StandardError => e
      Rails.logger.error("Error fetching libraries for server #{server['name']}: #{e.message}")
      []
    end
  end

  def select_best_connection(connections)
    # Try to find a public connection first
    public_connection = connections.find { |conn| !conn['local'] && !conn['relay'] }
    return public_connection['uri'] if public_connection

    # If no public connection, try a local connection
    local_connection = connections.find { |conn| conn['local'] }
    return local_connection['uri'] if local_connection

    # If no local connection, use a relay connection as a last resort
    relay_connection = connections.find { |conn| conn['relay'] }
    return relay_connection['uri'] if relay_connection

    # If no connection found, return nil
    Rails.logger.error("No suitable connection found")
    nil
  end

  def fetch_movies_from_library(user, library)
    Rails.logger.info("Fetching movies from library: #{library[:title]}")
    connection = Faraday.new(url: library[:uri], request: { timeout: 30, open_timeout: 10 }) do |faraday|
      faraday.request :url_encoded
      faraday.adapter Faraday.default_adapter
    end

    begin
      response = connection.get("/library/sections/#{library[:section_id]}/all") do |req|
        req.headers['Accept'] = 'application/json'
        req.headers['X-Plex-Token'] = library[:access_token]
        req.headers['X-Plex-Client-Identifier'] = user.plex_client_id
      end

      Rails.logger.info("Response status from /library/sections/#{library[:section_id]}/all: #{response.status}")

      if response.status == 200
        movies = JSON.parse(response.body)['MediaContainer']['Metadata']
        
        Rails.logger.info("Found #{movies.length} movies in library #{library[:title]}")
        movies.each do |movie_data|
          create_or_update_movie(user, movie_data, library)
        end
      else
        Rails.logger.error("Failed to fetch movies for library #{library[:title]}: #{response.body}")
      end
    rescue Faraday::ConnectionFailed => e
      Rails.logger.error("Connection failed for library #{library[:title]}: #{e.message}")
    rescue StandardError => e
      Rails.logger.error("Error fetching movies for library #{library[:title]}: #{e.message}")
    end
  end

  def create_or_update_movie(user, movie_data, library)
    # Use find_or_create_by! with a transaction to prevent race conditions
    Movie.transaction do
      movie = Movie.find_or_create_by!(plex_id: movie_data['ratingKey']) do |m|
        m.title = movie_data['title']
        m.genres = movie_data['Genre']&.map { |g| g['tag'] } || []
        m.year = movie_data['year']
        m.duration = movie_data['duration']
        m.tagline = movie_data['tagline']
        m.summary = movie_data['summary']
        m.content_rating = movie_data['contentRating']
        m.audience_rating = movie_data['audienceRating']
        m.rating = movie_data['rating']
      end

      # Update existing movie if attributes have changed
      if movie.persisted?
        movie.update!(
          title: movie_data['title'],
          genres: movie_data['Genre']&.map { |g| g['tag'] } || [],
          year: movie_data['year'],
          duration: movie_data['duration'],
          tagline: movie_data['tagline'],
          summary: movie_data['summary'],
          content_rating: movie_data['contentRating'],
          audience_rating: movie_data['audienceRating'],
          rating: movie_data['rating']
        )
      end

      # Handle user associations
      movie.user_ids |= [user.id] # Add user.id if not already present

      # Update watched status
      if movie_data['viewCount'].to_i > 0
        movie.watched_by_user_ids |= [user.id]
      else
        movie.watched_by_user_ids -= [user.id]
      end

      movie.save!
      Rails.logger.info("Created or updated movie: #{movie_data['title']} (Plex ID: #{movie_data['ratingKey']})")
    end
  rescue ActiveRecord::RecordNotUnique => e
    Rails.logger.error("Duplicate movie record attempted: #{e.message}")
    retry
  end
end