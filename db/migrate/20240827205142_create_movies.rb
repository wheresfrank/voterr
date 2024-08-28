class CreateMovies < ActiveRecord::Migration[7.1]
  def change
    create_table :movies do |t|
      t.string :title
      t.string :plex_id
      t.references :session, null: false, foreign_key: true

      t.timestamps
    end
  end
end
