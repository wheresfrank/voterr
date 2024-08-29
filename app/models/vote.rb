class Vote < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :movie
  belongs_to :session

  validates :guest_name, presence: true, unless: -> { user.present? }
  validates :positive, inclusion: { in: [true, false] }
end
