class Auth::SessionsController < ApplicationController
  def new
  end

  def destroy
    reset_session
    cookies.delete(:remember_token)
    redirect_to root_path, notice: "로그아웃되었습니다."
  end
end
