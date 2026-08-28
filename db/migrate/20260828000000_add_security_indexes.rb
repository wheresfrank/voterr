class AddSecurityIndexes < ActiveRecord::Migration[8.0]
  def change
    # Enforce invite-token uniqueness at the DB level (the model validation
    # alone can race under concurrent session creation).
    add_index :sessions, :session_token, unique: true, name: "index_sessions_on_session_token"

    # Case-insensitive guest-name uniqueness per session, enforced at the DB
    # level (guest_vote checks with LOWER(name); this closes the race window).
    add_index :voters, "session_id, LOWER(name)", unique: true,
      name: "index_voters_on_session_id_and_lower_name"
  end
end