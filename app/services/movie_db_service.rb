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
    movie = self.search_movie(query, year = nil, page = 1)
    return unless movie

    poster_path = movie['poster_path']
    return nil if poster_path.nil? || poster_path.empty?
    "#{IMAGE_BASE_URL}#{size}#{poster_path}"
  end
  
end
