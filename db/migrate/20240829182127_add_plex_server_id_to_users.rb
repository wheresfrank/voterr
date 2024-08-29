class AddPlexServerIdToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :plex_server_id, :string
  end
end
