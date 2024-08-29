class ApplicationController < ActionController::Base
  helper_method :current_user, :logged_in?

  def current_user
    if session[:user_id]
      begin
        @current_user ||= User.find(session[:user_id])
      rescue ActiveRecord::RecordNotFound
        session[:user_id] = nil
        @current_user = nil
      end
    end
  end

  def logged_in?
    !!current_user
  end

  def require_login
    unless logged_in?
      redirect_to new_plex_auth_path, alert: "You must be logged in to access this section"
    end
  end
end