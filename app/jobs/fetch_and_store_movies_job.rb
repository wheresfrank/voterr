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
        movies.each do |movie|
          create_or_update_movie(user, movie, library)
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

  def create_or_update_movie(user, movie, library)
    user_movie = user.movies.find_or_initialize_by(plex_id: movie['ratingKey'])
    user_movie.update(
      title: movie['title'],
      poster_url: "#{library[:uri]}#{movie['thumb']}?X-Plex-Token=#{library[:access_token]}",
      genres: movie['Genre']&.map { |g| g['tag'] } || [],
      year: movie['year'],
      duration: movie['duration'],
      tagline: movie['tagline'],
      summary: movie['summary'],
      content_rating: movie['contentRating'],
      audience_rating: movie['audienceRating'],
      rating: movie['rating'],
      unwatched: movie['viewCount'].to_i == 0
    )
    Rails.logger.info("Created or updated movie: #{movie['title']}")
  end
end