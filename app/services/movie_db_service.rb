require 'uri'
require 'net/http'

class MovieDbService
  BASE_URL = "https://api.themoviedb.org/3"
  IMAGE_BASE_URL = "https://image.tmdb.org/t/p/"
  API_KEY = ENV['TMDB_ACCESS_TOKEN']

  def self.search_movie(query, year = nil, page = 1)
    url = URI("#{BASE_URL}/search/movie")
    params = {
      query: query,
      include_adult: false,
      language: 'en-US',
      page: page
    }
    params[:primary_release_year] = year if year

    url.query = URI.encode_www_form(params)

    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true

    request = Net::HTTP::Get.new(url)
    request["accept"] = 'application/json'
    request["Authorization"] = "Bearer #{API_KEY}"

    response = http.request(request)
    movies = JSON.parse(response.body)
    movie = movies['results'].first
  end

  def self.get_poster_url(query, year = nil, size = "w200")
    movie = self.search_movie(query, year, page = 1)
    return unless movie

    poster_path = movie['poster_path']
    return nil if poster_path.nil? || poster_path.empty?
    "#{IMAGE_BASE_URL}#{size}#{poster_path}"
  end

  # Used on the public landing page for decorative poster fan (no user library yet).
  def self.trending_poster_urls(limit: 5, size: "w342")
    return [] if API_KEY.blank?

    url = URI("#{BASE_URL}/trending/movie/week")
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    request = Net::HTTP::Get.new(url)
    request["accept"] = "application/json"
    request["Authorization"] = "Bearer #{API_KEY}"

    response = http.request(request)
    return [] unless response.is_a?(Net::HTTPSuccess)

    data = JSON.parse(response.body)
    (data["results"] || []).first(limit).filter_map do |movie|
      path = movie["poster_path"]
      next if path.blank?

      "#{IMAGE_BASE_URL}#{size}#{path}"
    end
  rescue JSON::ParserError, SocketError, Net::OpenTimeout, Net::ReadTimeout
    []
  end
end
