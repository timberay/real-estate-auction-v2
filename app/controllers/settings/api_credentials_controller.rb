module Settings
  class ApiCredentialsController < ApplicationController
    def create
      @credential = current_user.api_credentials.build(credential_params)
      if @credential.save
        redirect_to settings_data_sources_path, notice: "데이터 소스가 설정되었습니다."
      else
        redirect_to settings_data_sources_path, alert: "설정에 실패했습니다."
      end
    end

    def update
      credential = find_credential
      if credential.update(credential_params)
        redirect_to settings_data_sources_path, notice: "설정이 업데이트되었습니다."
      else
        redirect_to settings_data_sources_path, alert: "업데이트에 실패했습니다."
      end
    end

    def destroy
      find_credential.destroy!
      redirect_to settings_data_sources_path, notice: "데이터 소스 설정이 삭제되었습니다."
    end

    def verify
      credential = find_credential
      CredentialVerificationJob.perform_later(credential)
      redirect_to settings_data_sources_path, notice: "키 검증을 시작했습니다."
    end

    private

    def find_credential
      current_user.api_credentials.find(params[:id])
    end

    def credential_params
      params.expect(api_credential: [ :provider_name, :api_key, :api_secret, :enabled ])
    end
  end
end
