class AddUserIdToMovies < ActiveRecord::Migration[7.1]
  def change
    add_reference :movies, :user, null: false, foreign_key: true
  end
end
