class BroadcastUpdateJob < ApplicationJob
  queue_as :default

  def perform(session_id)
    session = Session.find(session_id)
    
    # Broadcast voters panel update
    Turbo::StreamsChannel.broadcast_update_to(
      session,
      target: "voters-session-#{session.id}",
      partial: "sessions/voters",
      locals: { session: session }
    )

    # Broadcast session panel update
    Turbo::StreamsChannel.broadcast_update_to(
      session,
      target: "session_panel_#{session.id}",
      partial: "sessions/voting_stats",
      locals: { session: session, user: session.user }
    )
  end
end
