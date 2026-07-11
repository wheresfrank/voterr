require "test_helper"

class VoteTest < ActiveSupport::TestCase
  test "a vote requires an open session and a session movie" do
    user = User.create!(email: "vote-#{SecureRandom.hex(4)}@example.com", name: "Host")
    session = user.sessions.create!(session_name: "Vote validation")
    voter = session.voters.create!(name: "Host", user: user, session_owner: true)
    movie = Movie.create!(title: "Candidate", plex_id: "vote-#{SecureRandom.hex(4)}", user_ids: [user.id])

    vote = session.votes.build(movie: movie, voter: voter, user: user, positive: true)
    assert_not vote.valid?

    session.movies << movie
    session.update!(voting_started_at: Time.current)
    assert vote.valid?
  end
end
