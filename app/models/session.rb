class Session < ApplicationRecord
  belongs_to :user
  belongs_to :winner, polymorphic: true, optional: true

  validates :session_name, presence: true
  validates :session_token, presence: true, uniqueness: true

  before_validation :generate_session_token, on: :create

  private

  def generate_session_token
    self.session_token ||= SecureRandom.hex(10)
  end
end
