class CreateJoinTableMoviesSessions < ActiveRecord::Migration[7.1]
  def change
    create_join_table :movies, :sessions do |t|
      # t.index [:movie_id, :session_id]
      # t.index [:session_id, :movie_id]
    end
  end
end
