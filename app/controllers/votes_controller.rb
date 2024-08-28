class VotesController < ApplicationController
  before_action :require_login

  def create
    @session = Session.find(params[:session_id])
    @movie_id = params[:movie_id]

    @vote = @session.votes.create(user: current_user, movie_id: @movie_id)

    if @vote.save
      redirect_to @session, notice: 'Your vote has been recorded!'
    else
      redirect_to @session, alert: 'There was an issue recording your vote.'
    end
  end
end