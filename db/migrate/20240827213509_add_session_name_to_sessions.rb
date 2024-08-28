class AddSessionNameToSessions < ActiveRecord::Migration[7.1]
  def change
    add_column :sessions, :session_name, :string
  end
end
