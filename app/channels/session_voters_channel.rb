class SessionVotersChannel < ApplicationCable::Channel
  def subscribed
    stream_from "session_voters_#{params[:session_id]}"
  end
end