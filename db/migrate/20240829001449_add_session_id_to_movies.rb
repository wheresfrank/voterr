class AddSessionIdToMovies < ActiveRecord::Migration[7.1]
  def change
    add_reference :movies, :session, null: false, foreign_key: true
  end
end
