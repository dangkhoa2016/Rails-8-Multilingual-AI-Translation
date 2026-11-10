class PreferencesController < ApplicationController
  skip_before_action :require_admin!, only: :update

  def update
    if params.key?(:ui_locale)
      return invalid_preference unless params[:ui_locale].to_s.in?(%w[en vi])
      cookies.signed[:ui_locale] = cookie_options.merge(value: params[:ui_locale].to_s)
    elsif params.key?(:ui_theme)
      return invalid_preference unless params[:ui_theme].to_s.in?(%w[light dark auto])
      cookies.signed[:ui_theme] = cookie_options.merge(value: params[:ui_theme].to_s)
    else
      return invalid_preference
    end

    # Never follow a user-supplied URL or a cross-site Referer.
    destination = params[:return_to].to_s
    destination = root_path unless destination.start_with?("/") &&
      !destination.start_with?("//") && !destination.match?(/[\r\n\\]/)
    respond_to do |format|
      format.json { head :no_content }
      format.html { redirect_to destination, status: :see_other }
    end
  end

  private

  def cookie_options
    { expires: 1.year.from_now, secure: Rails.env.production?, same_site: :lax, httponly: true }
  end

  def invalid_preference
    head :unprocessable_entity
  end
end
