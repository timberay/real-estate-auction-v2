class Auth::SessionsController < ApplicationController
  def new
    session[:pending_post_action] = params[:pending] if params[:pending].present?
  end

  def destroy
    reset_session
    cookies.delete(:remember_token)
    redirect_to root_path, notice: "로그아웃되었습니다."
  end
end
