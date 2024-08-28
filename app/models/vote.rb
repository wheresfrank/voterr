class Vote < ApplicationRecord
  belongs_to :user
  belongs_to :movie
  belongs_to :session
end
