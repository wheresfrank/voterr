class Movie < ApplicationRecord
  has_and_belongs_to_many :sessions
  has_many :votes, dependent: :destroy

  attribute :user_ids, :integer, array: true, default: []
  attribute :watched_by_user_ids, :integer, array: true, default: []

  scope :for_user, ->(user_id) { where('? = ANY(user_ids)', user_id) }
  scope :unwatched_by_user, ->(user_id) { where('? = ANY(user_ids) AND NOT ? = ANY(watched_by_user_ids)', user_id, user_id) }

  def unwatched_by?(user)
    user_ids.include?(user.id) && !watched_by_user_ids.include?(user.id)
  end

  def mark_as_watched_by(user)
    self.watched_by_user_ids |= [user.id] # Add user.id if not already present
    save
  end

  def mark_as_unwatched_by(user)
    self.watched_by_user_ids -= [user.id]
    save
  end
end