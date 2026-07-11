class Vote < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :voter, optional: true
  belongs_to :movie
  belongs_to :session

  validates :positive, inclusion: { in: [true, false] }
  validates :movie_id, uniqueness: { scope: [:session_id, :voter_id] }
  validate :user_or_voter_present
  validate :session_is_open
  validate :participants_belong_to_session

  private

  def user_or_voter_present
    errors.add(:base, "Either user or voter must be present") unless user_id.present? || voter_id.present?
  end

  def session_is_open
    errors.add(:session, "is not open for voting") if session && !session.voting?
  end

  def participants_belong_to_session
    errors.add(:voter, "does not belong to this session") if voter && voter.session_id != session_id
    errors.add(:movie, "does not belong to this session") if movie && session && !session.movies.exists?(movie.id)
  end
end
