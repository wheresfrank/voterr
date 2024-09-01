class AddSessionOwnerToVoters < ActiveRecord::Migration[7.1]
  def change
    add_column :voters, :session_owner, :boolean
  end
end
