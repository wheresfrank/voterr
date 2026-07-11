require "test_helper"

class SessionTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "mechanics-#{SecureRandom.hex(4)}@example.com", name: "Host")
    @session = @user.sessions.create!(session_name: "Mechanics test")
    @host = @session.voters.create!(name: "Host", user: @user, session_owner: true)
  end

  test "the roster accepts guests only before voting starts" do
    assert @session.lobby?
    assert @session.voters.create(name: "Guest", user: @user).valid?

    @session.update!(voting_started_at: Time.current)
    late_guest = @session.voters.build(name: "Late guest", user: @user)

    assert_not late_guest.valid?
    assert_includes late_guest.errors[:session], "has already started voting"
  end

  test "finalists are ranked by positive votes" do
    movies = 3.times.map do |index|
      Movie.create!(title: "Candidate #{index}", plex_id: "candidate-#{SecureRandom.hex(4)}", user_ids: [@user.id])
    end
    @session.movies << movies
    guest = @session.voters.create!(name: "Guest", user: @user)
    @session.update!(voting_started_at: Time.current)

    @session.votes.create!(movie: movies[0], voter: @host, user: @user, positive: true)
    @session.votes.create!(movie: movies[0], voter: guest, user: @user, positive: true)
    @session.votes.create!(movie: movies[1], voter: @host, user: @user, positive: true)
    @session.votes.create!(movie: movies[2], voter: @host, user: @user, positive: false)

    assert_equal [movies[0].id, movies[1].id], @session.top_movies_by_positive_votes.pluck(:id)
    assert_equal 2, @session.positive_vote_counts[movies[0].id]
  end
end
