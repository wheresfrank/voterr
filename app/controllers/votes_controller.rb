class VotesController < ApplicationController
  def create
    session_token = params[:session_token]
    movie_id = params[:movie_id]
    positive = params[:positive]

    @session = Session.find_by(session_token: session_token)
    @movie = Movie.find(movie_id)

    # Ensure the movie is associated with the session
    @session.movies << @movie unless @session.movies.include?(@movie)

    # Find or create the voter
    @voter = if current_user
               @session.voters.find_or_create_by(user: current_user)
             else
               @session.voters.find_or_create_by(name: session[:guest_name])
             end

    # Create the vote
    @vote = Vote.new(
      movie: @movie,
      session: @session,
      positive: positive,
      voter: @voter
    )

    # Set the user if it's a logged-in user
    @vote.user = current_user if current_user

    if @vote.save
      if @session.all_participants_voted_for_same_movie?
        @session.update(winner: @movie)
        redirect_to session_path(@session), notice: "We have a winner!"
      else
        @next_movie = @session.next_unvoted_movie(current_user || @voter)
        
        respond_to do |format|
          format.turbo_stream do
            if @next_movie
              render turbo_stream: [
                turbo_stream.replace("movie_#{@movie.id}", partial: "sessions/voted_movie", locals: { movie: @movie }),
                turbo_stream.replace("current_movie", partial: "sessions/movie", locals: { movie: @next_movie, session: @session })
              ]
            else
              render turbo_stream: [
                turbo_stream.replace("movie_#{@movie.id}", partial: "sessions/voted_movie", locals: { movie: @movie }),
                turbo_stream.replace("current_movie", html: "<p>No more movies to vote on in this session.</p>")
              ]
            end
          end
          format.html { redirect_to session_path(@session), notice: "Vote recorded!" }
        end
      end
    else
      redirect_to session_path(@session), alert: "Error recording vote: #{@vote.errors.full_messages.join(', ')}"
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