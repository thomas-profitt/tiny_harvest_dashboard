class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  def request_from_local_network?
    request.ip =~ /\A192\.168\.\d*\.\d*\z/ ? true : false
  end
end
