class Vote < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :voter, optional: true
  belongs_to :movie
  belongs_to :session

  validates :positive, inclusion: { in: [true, false] }
  validate :user_or_voter_present

  private

  def user_or_voter_present
    errors.add(:base, "Either user or voter must be present") unless user_id.present? || voter_id.present?
  end
end
