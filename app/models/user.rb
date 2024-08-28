class User < ApplicationRecord
  before_create :generate_plex_client_id
  has_many :sessions, dependent: :destroy

  private

  def generate_plex_client_id
    self.plex_client_id ||= SecureRandom.uuid
  end
end
