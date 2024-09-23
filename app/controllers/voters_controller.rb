class VotersController < ApplicationController
  def destroy
    @session = Session.find(params[:session_id])
    @voter = @session.voters.find(params[:id])

    if @voter.destroy
      # Enqueue the job to broadcast the update
      BroadcastUpdateJob.perform_later(@session.id)

      flash[:notice] = "#{@voter.name} has been removed from the session."
    else
      flash[:alert] = "There was an issue removing the voter."
    end

    redirect_to session_path(@session)
  end
end