class SessionsController < ApplicationController
  before_action :require_login, except: [:join, :guest_vote, :show_guest]

  def new
    @session = Session.new
  end

  def create
    @session = current_user.sessions.new(session_params)
    if @session.save
      selected_movies = current_user.movies.sample(5)
      @session.movies << selected_movies

      redirect_to @session, notice: 'Session created successfully!'
    else
      render :new, alert: 'Failed to create session.'
    end
  end

  def show
    @user = current_user
    @session = Session.find(params[:id])

    # Fetch a movie from the session's movies, ensuring it's not yet voted on by the user
    @movie = @session.movies.where.not(id: @session.votes.where(user_id: @user.id).select(:movie_id)).sample
  end

  def show_guest
    @session = Session.find_by(session_token: params[:token])
    @guest_name = session[:guest_name]

    # Fetch a movie from the session's movies, ensuring it's not yet voted on by the guest
    @movie = @session.movies.where.not(id: @session.votes.where(guest_name: @guest_name).select(:movie_id)).sample
  end

  def join
    @session = Session.find_by(session_token: params[:token])
    if @session.nil?
      redirect_to root_path, alert: "Session not found."
    end
  end

  def guest_vote
    @session = Session.find_by(session_token: params[:token])
    guest_name = params[:guest_name]
  
    if guest_name.blank?
      flash.now[:alert] = "Name can't be blank."
      render :join
    else
      session[:guest_name] = guest_name
      redirect_to show_guest_session_path(token: @session.session_token)
    end
  end

  private

  def session_params
    params.require(:session).permit(:session_name)
  end

  def require_login
    unless logged_in?
      redirect_to new_plex_auth_path, alert: "You must be logged in to access this section"
    end
  end
end