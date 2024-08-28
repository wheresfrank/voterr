class CreateUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :users do |t|
      t.string :email
      t.string :plex_token
      t.string :plex_client_id

      t.timestamps
    end
  end
end
