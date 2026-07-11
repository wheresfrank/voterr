class BroadcastUpdateJob < ApplicationJob
  queue_as :default

  def perform(session_id)
    session = Session.find(session_id)
    
    # Broadcast voters panel update
    Turbo::StreamsChannel.broadcast_update_to(
      session,
      target: "voters-session-#{session.id}",
      partial: "sessions/voters",
      locals: { session: session, host_controls: false }
    )

    Turbo::StreamsChannel.broadcast_update_to(
      session,
      :host,
      target: "voters-session-#{session.id}",
      partial: "sessions/voters",
      locals: { session: session, host_controls: true }
    )

    # Host-only ranking controls are broadcast on a private stream that guests
    # never subscribe to.
    Turbo::StreamsChannel.broadcast_update_to(
      session,
      :host,
      target: "session_panel_#{session.id}",
      partial: "sessions/voting_stats",
      locals: { 
        session: session, 
        user: session.user,
        host_controls: true
      }
    )
  end
end
