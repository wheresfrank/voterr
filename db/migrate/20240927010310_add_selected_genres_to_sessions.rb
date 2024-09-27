class AddSelectedGenresToSessions < ActiveRecord::Migration[7.1]
  def change
    add_column :sessions, :selected_genres, :text, array: true, default: []
  end
end
