class SessionsController < ApplicationController
  before_action :require_login, except: [:join, :show_guest, :guest_vote]

  # Unauthenticated lobby joins are limited per IP to prevent voter spam
  # (Rails 7.2+/8 built-in rate limiting; uses Rails.cache).
  rate_limit to: 10, within: 1.minute, only: :guest_vote

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
    @session = current_user.sessions.find(params[:id])
    voter = @session.voters.find_by(user: current_user)
    @movie = @session.next_unvoted_movie(voter) if @session.voting? && voter
  end

  def start_voting
    @session = current_user.sessions.find(params[:id])

    if @session.closed?
      redirect_to session_path(@session), alert: "This session has already ended."
    elsif @session.voters.count < 2
      redirect_to session_path(@session), alert: "Invite at least one guest before starting the vote."
    elsif @session.voting?
      redirect_to session_path(@session), notice: "Voting is already in progress."
    else
      @session.update!(voting_started_at: Time.current)
      broadcast_session_update(@session)
      redirect_to session_path(@session), notice: "Voting started. The guest list is now locked."
    end
  end

  def select_winner
    @session = current_user.sessions.find(params[:id])
    finalist = @session.top_movies_by_positive_votes.find_by(id: params[:movie_id])

    if !@session.voting?
      redirect_to session_path(@session), alert: "Voting is not currently open."
    elsif finalist.nil?
      redirect_to session_path(@session), alert: "Choose one of the current top three movies."
    else
      @session.update!(winner: finalist, voting_closed_at: Time.current)
      broadcast_session_update(@session)
      redirect_to session_path(@session), notice: "#{finalist.title} won. Voting is closed."
    end
  end

  def destroy
    # Scope to the current user's sessions: any signed-in user must not be
    # able to delete sessions they do not own.
    @session = current_user.sessions.find(params[:id])
    @session.destroy
    redirect_to sessions_path, notice: "Session was successfully deleted."
  end

  def show_guest
    @session = Session.find_by(session_token: params[:token])
    return redirect_to(root_path, alert: "Session not found.") unless @session

    @guest_name = session[:guest_name]
    voter = @session.voters.find_by(name: @guest_name)
    return redirect_to(join_session_path(token: params[:token]), alert: "Join the session before voting.") unless voter

    @movie = @session.next_unvoted_movie(voter) if @session.voting?
  end

  def join
    @session = Session.find_by(session_token: params[:token])
    if @session.nil?
      redirect_to root_path, alert: "Session not found."
    elsif @session.voting? || @session.closed?
      redirect_to root_path, alert: "This room is no longer accepting new guests."
    end
  end

  def guest_vote
    @session = Session.find_by(session_token: params[:token])
    guest_name = params[:guest_name].to_s.strip

    if @session.nil?
      return redirect_to root_path, alert: "Session not found."
    elsif !@session.lobby?
      return redirect_to root_path, alert: "The guest list is locked because voting has started."
    end

    if guest_name.blank?
      flash.now[:alert] = "Name can't be blank."
      render :join
    else
      existing_voter = @session.voters.where("LOWER(name) = ?", guest_name.downcase).first
      if existing_voter
        flash.now[:alert] = "That name is already in the room. Please use another name."
        return render :join, status: :unprocessable_entity
      end

      voter = @session.voters.create(name: guest_name, user: @session.user, session_owner: false)
      
      if voter.persisted?
        session[:guest_name] = guest_name

        Turbo::StreamsChannel.broadcast_update_to(
          @session, 
          target: "voters-session-#{@session.id}",
          partial: "sessions/voters", 
          locals: { session: @session, host_controls: false }
        )

        Turbo::StreamsChannel.broadcast_update_to(
          @session,
          :host,
          target: "voters-session-#{@session.id}",
          partial: "sessions/voters",
          locals: { session: @session, host_controls: true }
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

  def broadcast_session_update(session)
    Turbo::StreamsChannel.broadcast_update_to(
      session,
      target: "session_#{session.id}",
      partial: "sessions/vote",
      locals: { session: session }
    )
  end

  def session_params
    params.require(:session).permit(:session_name, :only_unwatched, genres: [])
  end

  def require_login
    unless current_user
      redirect_to new_plex_auth_path, alert: "You must be logged in to access this page."
    end
  end
end
