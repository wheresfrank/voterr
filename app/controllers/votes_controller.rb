class VotesController < ApplicationController
  rate_limit to: 60, within: 1.minute

  def create
    session_token = params[:session_token]
    movie_id = params[:movie_id]

    @session = Session.find_by(session_token: session_token)
    return redirect_to(root_path, alert: "Session not found.") unless @session
    return redirect_to(root_path, alert: "Voting is not open.") unless @session.voting?

    @movie = @session.movies.find_by(id: movie_id)
    return redirect_to(root_path, alert: "That movie is not part of this voting session.") unless @movie

    # Find the voter by either the current user's ID or the guest's name
    @voter = if current_user
               @session.voters.find_by(user: current_user)
             else
               @session.voters.find_by(name: session[:guest_name])
             end
    return redirect_to(root_path, alert: "You are not part of this voting session.") unless @voter

    # Create the vote, associating it with the correct session, movie, and voter
    @vote = @session.votes.find_or_initialize_by(movie: @movie, voter: @voter)
    @vote.assign_attributes(
      # Cast explicitly: any string other than the documented falsey values
      # must not silently become `true`.
      positive: ActiveModel::Type::Boolean.new.cast(params[:positive]),
      guest_name: @voter.name,
      user: @session.user
    )
    @vote.save!

    # Broadcast updates to all participants using the job
    BroadcastUpdateJob.perform_later(@session.id)

    @next_movie = @session.next_unvoted_movie(@voter)
    if @next_movie
      render turbo_stream: turbo_stream.replace("movie_#{@movie.plex_id}", partial: "sessions/movie", locals: { movie: @next_movie, session: @session })
    else
      if remaining_movies.any?
        add_new_movies_to_session(remaining_movies)
        @next_movie = @session.next_unvoted_movie(@voter)
        render turbo_stream: turbo_stream.replace("movie_#{@movie.plex_id}", partial: "sessions/movie", locals: { movie: @next_movie, session: @session })
      else
        waiting_html = helpers.content_tag(:div, class: "app-empty-state") do
          content_tag(:span, "✓") +
            content_tag(:h2, "You’re caught up") +
            content_tag(:p, "Waiting for the host to choose from the group’s top movies.")
        end
        render turbo_stream: turbo_stream.replace("movie_#{@movie.plex_id}", html: waiting_html)
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
