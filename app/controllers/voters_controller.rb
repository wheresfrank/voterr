class VotersController < ApplicationController
  def destroy
    @session = Session.find(params[:session_id])
    @voter = @session.voters.find(params[:id])

    if @voter.destroy
      Turbo::StreamsChannel.broadcast_update_to(
        @session,
        target: "voters-session-#{@session.id}",
        partial: "sessions/voters",
        locals: { session: @session }
      )

      flash[:notice] = "#{@voter.name} has been removed from the session."
    else
      flash[:alert] = "There was an issue removing the voter."
    end

    redirect_to session_path(@session)
  end
end