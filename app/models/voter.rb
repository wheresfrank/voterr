class Voter < ApplicationRecord
  belongs_to :session
  belongs_to :user, optional: true
  has_many :votes, dependent: :destroy

  validates :name, presence: true
  validates :name, uniqueness: { scope: :session_id, case_sensitive: false }
  validate :session_is_accepting_voters, on: :create

  private

  def session_is_accepting_voters
    errors.add(:session, "has already started voting") if session && !session.lobby?
  end
end
