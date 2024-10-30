class User < ApplicationRecord
  before_create :generate_plex_client_id
  has_many :sessions, dependent: :destroy
  has_many :votes, dependent: :destroy
  has_many :voted_movies, through: :votes, source: :movie

  def movies
    Movie.for_user(id)
  end

  def unwatched_movies
    Movie.unwatched_by_user(id)
  end

  private

  def generate_plex_client_id
    self.plex_client_id ||= SecureRandom.uuid
  end
end
