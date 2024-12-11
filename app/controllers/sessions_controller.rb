class SessionsController < ApplicationController
  before_action :require_login, except: [:join, :show_guest, :guest_vote]

  def new
    @session = Session.new
  end

  def create
    @session = current_user.sessions.new(session_params)
    @movies = current_user.movies

    # Filter by genres only if genres are selected
    if params[:session][:genres].present? && params[:session][:genres].reject(&:blank?).any?
      @session.selected_genres = params[:session][:genres].reject(&:blank?)
      @movies = @movies.where("genres && ARRAY[?]::varchar[]", @session.selected_genres)
    end

    # Only show unwatched based on session.only_watched
    @movies = @movies.unwatched_by_user(current_user.id) if @session.only_unwatched

    if @session.save
      @session.voters.create!(name: current_user.name, user: @session.user, session_owner: true)

      selected_movies = @movies.sample(5)
      @session.movies << selected_movies
      
      redirect_to session_path(@session), notice: 'Session created successfully!'
    else
      @available_genres = current_user.movies.pluck(:genres).flatten.uniq.sort
      render :new, status: :unprocessable_entity
    end
  end

  def index
    @session = Session.new
    @sessions = current_user.sessions
    @available_genres = current_user.movies.pluck(:genres).flatten.uniq.sort
  end

  def show
    @user = current_user
    @session = Session.find(params[:id])
    @movie = Movie.unwatched_by_user(@user.id)
                  .where.not(id: @session.votes.where(user_id: @user.id).select(:movie_id))
                  .sample
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
      
      # Create voter and ensure it exists
      voter = @session.voters.find_by(name: guest_name)
      voter ||= @session.voters.create(name: guest_name, user: @session.user, session_owner: false)
      
      if voter.persisted?
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
      else
        flash.now[:alert] = "Unable to create voter: #{voter.errors.full_messages.join(', ')}"
        render :join
      end
    end
  end

  def logout
    session[:user_id] = nil
    redirect_to root_path, notice: "You have been logged out."
  end
  
  private

  def session_params
    params.require(:session).permit(:session_name, :only_unwatched, genres: [])
  end

  def require_login
    unless current_user
      redirect_to new_plex_auth_path, alert: "You must be logged in to access this page."
    end
  end
end