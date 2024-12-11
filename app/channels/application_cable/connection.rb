module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
    end

    private
      def find_verified_user
        if verified_user = User.find_by(id: session['user_id'])
          verified_user
        elsif session[:guest_name].present?
          GuestUser.new(session[:guest_name])
        else
          reject_unauthorized_connection
        end
      end

      def session
        @session ||= cookies.encrypted[Rails.application.config.session_options[:key]]&.with_indifferent_access
      end
  end
end
