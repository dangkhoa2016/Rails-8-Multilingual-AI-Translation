module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      # The cookie is encrypted and authenticated by Rails' CookieStore.
      # Never accept a bare user ID or an unsigned stream name as authorization.
      session_data = cookies.encrypted["_translation_workspace_session"]
      self.current_user = SessionSecurity.user_from(session_data)
      reject_unauthorized_connection unless current_user
    end
  end
end
