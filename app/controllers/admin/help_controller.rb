module Admin
  class HelpController < BaseController
    def index
      # Help content is local and read-only: never contact inference endpoints.
      response.cache_control[:no_store] = true
    end
  end
end
