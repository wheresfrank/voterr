class RemoveSessionIdFromMovies < ActiveRecord::Migration[7.1]
  def change
    remove_column :movies, :session_id, :bigint
  end
end
