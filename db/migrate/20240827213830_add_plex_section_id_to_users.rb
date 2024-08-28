class AddPlexSectionIdToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :plex_section_id, :string
  end
end
