class BroadcastUpdateJob < ApplicationJob
  queue_as :default

  def perform(session_id)
    session = Session.find(session_id)

    # Lobby state: refresh the roster card (guest count + list) and the
    # host's start controls so they stay in sync after a voter is removed.
    Turbo::StreamsChannel.broadcast_update_to(
      session,
      target: "lobby_roster_#{session.id}",
      partial: "sessions/lobby_roster",
      locals: { session: session, host_controls: false }
    )

    Turbo::StreamsChannel.broadcast_update_to(
      session, :host,
      target: "lobby_roster_#{session.id}",
      partial: "sessions/lobby_roster",
      locals: { session: session, host_controls: true }
    )

    Turbo::StreamsChannel.broadcast_update_to(
      session, :host,
      target: "lobby_controls_#{session.id}",
      partial: "sessions/lobby_controls",
      locals: { session: session, host_controls: true }
    )

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
