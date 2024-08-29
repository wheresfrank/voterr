class Session < ApplicationRecord
  belongs_to :user
  belongs_to :winner, polymorphic: true, optional: true
  has_and_belongs_to_many :movies
  has_many :votes, dependent: :destroy

  validates :session_name, presence: true
  validates :session_token, presence: true, uniqueness: true

  before_validation :generate_session_token, on: :create

  def unique_participants
    (votes.pluck(:guest_name).uniq + votes.where.not(user_id: nil).pluck(:user_id).uniq).count
  end

  def all_participants_voted_for_same_movie?
    votes.group(:movie_id).having('count(distinct guest_name) + count(distinct user_id) = ?', unique_participants).exists?
  end

  private

  def generate_session_token
    self.session_token ||= SecureRandom.hex(10)
  end
end