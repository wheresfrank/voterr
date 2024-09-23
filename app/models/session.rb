class Session < ApplicationRecord
  belongs_to :user
  belongs_to :winner, polymorphic: true, optional: true
  has_and_belongs_to_many :movies
  has_many :votes, dependent: :destroy
  has_many :voters, dependent: :destroy

  validates :session_name, presence: true
  validates :session_token, presence: true, uniqueness: true

  before_validation :generate_session_token, on: :create

  scope :finished, -> { where.not(winner_id: nil).order(created_at: :desc) }
  scope :recent_winners, -> { where.not(winner_id: nil).order(created_at: :desc).limit(10) }
  scope :in_progress, -> { where(winner_id: nil).order(created_at: :desc) }

  def all_participants_voted_for_same_movie?
    total_voters = voters.count
    return false if total_voters < 2
  
    votes.where(positive: true)
         .group(:movie_id)
         .having('COUNT(DISTINCT voter_id) = ?', total_voters)
         .exists?
  end

  private

  def generate_session_token
    self.session_token ||= SecureRandom.hex(10)
  end
end