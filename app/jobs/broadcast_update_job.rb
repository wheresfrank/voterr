class BroadcastUpdateJob < ApplicationJob
  queue_as :default

  def perform(session_id)
    session = Session.find(session_id)
    Turbo::StreamsChannel.broadcast_update_to(
      session,
      target: "voters-session-#{session.id}",
      partial: "sessions/voters",
      locals: { session: session }
    )
  end
end
