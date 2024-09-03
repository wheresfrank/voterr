class AddOnlyWatchedToSessions < ActiveRecord::Migration[7.1]
  def change
    add_column :sessions, :only_unwatched, :boolean, default: false
  end
end
