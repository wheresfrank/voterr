class VotesController < ApplicationController
  def create
    session_token = params[:session_token]
    movie_id = params[:movie_id]
    guest_name = session[:guest_name] || params[:guest_name]

    @session = Session.find_by(session_token: session_token)
    @movie = @session.movies.find(movie_id)

    # Create the vote, associating it with the correct session and movie
    @vote = @session.votes.create!(
      movie: @movie,
      guest_name: guest_name,
      user_id: current_user&.id
    )

    if @session.all_participants_voted_for_same_movie?
      @session.update(winner: @movie)
      redirect_to session_winner_path(@session), notice: "#{@movie.title} is the winner!"
    else
      if all_movies_in_batch_voted?(@session, guest_name)
        add_new_movies_to_session(@session)
      end

      @next_movie = @session.movies.where.not(id: @session.votes.where(guest_name: guest_name).select(:movie_id)).sample
      if @next_movie
        render turbo_stream: turbo_stream.replace("movie_#{@movie.plex_id}", partial: "sessions/movie", locals: { movie: @next_movie, session: @session })
      else
        render turbo_stream: turbo_stream.replace("movie_#{@movie.plex_id}", partial: "sessions/no_more_movies")
      end
    end
  end

  private

  def all_movies_in_batch_voted?(session, guest_name)
    # Check if all movies in the current batch have been voted on by the guest
    session.movies.count == session.votes.where(guest_name: guest_name).count
  end

  def add_new_movies_to_session(session)
    # Find all movies that are not yet in the session
    remaining_movies = session.user.movies.where.not(id: session.movies.pluck(:id))
    
    # Add 5 random new movies to the session
    new_movies = remaining_movies.sample(5)
    session.movies << new_movies
  end
end