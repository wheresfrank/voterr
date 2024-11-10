class VotesController < ApplicationController
  def create
    session_token = params[:session_token]
    movie_id = params[:movie_id]

    @session = Session.find_by(session_token: session_token)
    @movie = Movie.find(movie_id)

    unless @session.movies.include?(@movie)
      @session.movies << @movie
    end

    # Find the voter by either the current user's ID or the guest's name
    @voter = if current_user
               @session.voters.find_by(user: current_user)
             else
               @session.voters.find_by(name: session[:guest_name])
             end

    # Create the vote, associating it with the correct session, movie, and voter
    @vote = @session.votes.create!(
      movie: @movie,
      voter_id: @voter.id,
      positive: params[:positive],
      guest_name: @voter.name,
      user: @session.user
    )

    # Broadcast updates to all participants using the job
    BroadcastUpdateJob.perform_later(@session.id)

    if @session.all_participants_voted_for_same_movie?
      @session.update(winner: @movie) if @session.winner.nil?
      render turbo_stream: turbo_stream.replace("session_#{@session.id}", partial: "sessions/vote", locals: { movie: @session.winner, session: @session })
    else
      @next_movie = @session.next_unvoted_movie(@voter)
      if @next_movie
        render turbo_stream: turbo_stream.replace("movie_#{@movie.plex_id}", partial: "sessions/movie", locals: { movie: @next_movie, session: @session })
      else
        if remaining_movies.any?
          add_new_movies_to_session(remaining_movies)
          @next_movie = @session.next_unvoted_movie(@voter)
          render turbo_stream: turbo_stream.replace("movie_#{@movie.plex_id}", partial: "sessions/movie", locals: { movie: @next_movie, session: @session })
        else
          render turbo_stream: turbo_stream.replace("movie_#{@movie.plex_id}", html: content_tag(:div, class: "notification is-info has-text-centered") do
            "You've voted on all available movies! Waiting for other participants..."
          end)
        end
      end
    end
  end


  private

  def all_movies_in_batch_voted?(session)
    # Check if every movie in the session has been positively voted on by all voters
    session.movies.each do |movie|
      return false unless session.votes.where(movie: movie).count == session.voters.count
    end
    true
  end

  def remaining_movies
    movies = @session.user.movies.where.not(id: @session.movies.pluck(:id))
    
    # Apply genre filter if genres were selected
    if @session.selected_genres.present?
      movies = movies.where("genres && ARRAY[?]::varchar[]", @session.selected_genres)
    end

    # Apply unwatched filter if applicable
    movies = movies.unwatched_by_user(@session.user.id) if @session.only_unwatched

    movies
  end

  def add_new_movies_to_session(movies)
    # Add 5 new random movies
    new_movies = movies.sample(5)
    @session.movies << new_movies
  end
end