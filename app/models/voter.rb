class Voter < ApplicationRecord
  belongs_to :session
  belongs_to :user, optional: true
  has_many :votes, dependent: :destroy

  validates :name, presence: true
end