class AddUserArraysToMovies < ActiveRecord::Migration[7.1]
  def change
    add_column :movies, :user_ids, :integer, array: true, default: []
    add_column :movies, :watched_by_user_ids, :integer, array: true, default: []
    add_index :movies, :user_ids, using: 'gin'
    add_index :movies, :watched_by_user_ids, using: 'gin'
  end
end
