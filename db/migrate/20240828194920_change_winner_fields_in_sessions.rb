class ChangeWinnerFieldsInSessions < ActiveRecord::Migration[7.1]
  def change
    change_column :sessions, :winner_type, :string, null: true
    change_column :sessions, :winner_id, :bigint, null: true
  end
end
