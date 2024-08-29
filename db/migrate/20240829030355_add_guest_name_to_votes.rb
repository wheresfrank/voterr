class AddGuestNameToVotes < ActiveRecord::Migration[7.1]
  def change
    add_column :votes, :guest_name, :string
  end
end
