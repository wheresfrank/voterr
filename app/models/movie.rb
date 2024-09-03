class Movie < ApplicationRecord
  belongs_to :user
  has_and_belongs_to_many :sessions
  has_many :votes, dependent: :destroy

  scope :unwatched, -> { where(unwatched: true) }
end