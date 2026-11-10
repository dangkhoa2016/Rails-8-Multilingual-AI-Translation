class ErrorsController < ApplicationController
  # Missing pages are public, including when the visitor is not signed in.
  skip_before_action :require_admin!

  def not_found
    render_not_found
  end
end
