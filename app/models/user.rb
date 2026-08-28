class User < ApplicationRecord
  # The Plex OAuth token grants full access to the user's Plex account, so it
  # must never be stored in plaintext. Uses Rails' built-in Active Record
  # Encryption (keys derive from secret_key_base when no explicit
  # active_record_encryption credentials are configured).
  #
  # Note: tokens stored before this change are unreadable after deploying;
  # they fail decryption and the import job logs an error until the user
  # re-authenticates with Plex (which writes a fresh, encrypted token).
  encrypts :plex_token

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
