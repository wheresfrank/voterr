class CreateSessions < ActiveRecord::Migration[7.1]
  def change
    create_table :sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :session_token
      t.references :winner, polymorphic: true, null: false

      t.timestamps
    end
  end
end
