module Settings
  class DataSourcesController < ApplicationController
    def show
      @providers = ApiCredential::PROVIDERS
      @credentials = current_user.api_credentials.index_by(&:provider_name)
    end
  end
end
