class AddVoterIdToVotes < ActiveRecord::Migration[7.1]
  def change
    add_reference :votes, :voter, null: false, foreign_key: true
  end
end
