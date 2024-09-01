class AllowNullSessionIdInMoviesSessions < ActiveRecord::Migration[7.1]
  def change
    change_column_null :movies_sessions, :session_id, true
  end
end
