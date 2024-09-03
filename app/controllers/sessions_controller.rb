class SessionsController < ApplicationController
  before_action :require_login, except: [:join, :show_guest, :guest_vote]

  def new
    @session = Session.new
  end

  def create
    @session = current_user.sessions.new(session_params)
    byebug
    @movies = @session.only_unwatched ? current_user.movies.unwatched : current_user.movies
    if @session.save
      # Create a voter for the main user
      @session.voters.create!(name: current_user.name, user: @session.user, session_owner: true)

      selected_movies = @movies.sample(5)
      @session.movies << selected_movies

      redirect_to @session, notice: 'Session created successfully!'
    else
      render :new, alert: 'Failed to create session.'
    end
  end

  def index
    @session = Session.new
    @sessions = current_user.sessions
  end

  def show
    @user = current_user
    @session = Session.find(params[:id])

    # Fetch a movie from the session's movies, ensuring it's not yet voted on by the user
    @movie = @session.movies.where.not(id: @session.votes.where(user_id: @user.id).select(:movie_id)).sample
  end

  def destroy
    @session = Session.find(params[:id])
    @session.destroy
    redirect_to sessions_path, notice: "Session was successfully deleted."
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
      voter = @session.voters.create!(name: guest_name, user: @session.user, session_owner: false) unless @session.voters.exists?(name: guest_name)
      @movie = @session.movies.where.not(id: voter.votes.select(:movie_id)).sample

      Turbo::StreamsChannel.broadcast_update_to(
        @session, 
        target: "voters-session-#{@session.id}",
        partial: "sessions/voters", 
        locals: { session: @session }
      )

      respond_to do |format|
        format.html { redirect_to show_guest_session_path(@session.session_token) }
        format.turbo_stream { render :show_guest, formats: :html }
      end
    end
  end

  def logout
    session[:user_id] = nil
    redirect_to root_path, notice: "You have been logged out."
  end
  
  private

  def session_params
    params.require(:session).permit(:session_name, :only_unwatched)
  end

  def require_login
    unless current_user
      redirect_to new_plex_auth_path, alert: "You must be logged in to access this page."
    end
  end
end