class AddWatchedToMovies < ActiveRecord::Migration[7.1]
  def change
    add_column :movies, :unwatched, :boolean, default: false
  end
end
