class AddYearAndDurationToMovies < ActiveRecord::Migration[7.1]
  def change
    add_column :movies, :year, :integer
    add_column :movies, :duration, :integer
  end
end
