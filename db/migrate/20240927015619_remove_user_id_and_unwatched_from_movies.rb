class RemoveUserIdAndUnwatchedFromMovies < ActiveRecord::Migration[7.1]
  def change
    remove_column :movies, :user_id, :bigint
    remove_column :movies, :unwatched, :boolean
  end
end
