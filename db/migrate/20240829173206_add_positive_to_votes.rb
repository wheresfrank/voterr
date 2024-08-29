class AddPositiveToVotes < ActiveRecord::Migration[7.1]
  def change
    add_column :votes, :positive, :boolean
  end
end
