class AddVotingStateToSessions < ActiveRecord::Migration[8.0]
  def up
    add_column :sessions, :voting_started_at, :datetime
    add_column :sessions, :voting_closed_at, :datetime

    execute <<~SQL.squish
      UPDATE sessions
      SET voting_started_at = sessions.created_at
      WHERE EXISTS (
        SELECT 1 FROM votes WHERE votes.session_id = sessions.id
      )
    SQL

    execute <<~SQL.squish
      UPDATE sessions
      SET voting_closed_at = sessions.updated_at
      WHERE winner_id IS NOT NULL
    SQL
  end

  def down
    remove_column :sessions, :voting_started_at
    remove_column :sessions, :voting_closed_at
  end
end
