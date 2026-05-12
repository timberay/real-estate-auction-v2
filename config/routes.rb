Rails.application.routes.draw do
  root "home#index"

  post "/csp_reports", to: "csp_reports#create"

  if Rails.env.test?
    post "/testing/sign_in", to: ->(env) {
      req = ActionDispatch::Request.new(env)
      req.session[:user_id] = req.params["user_id"].to_i
      [ 200, {}, [ "ok" ] ]
    }

    post "/testing/set_session", to: ->(env) {
      req = ActionDispatch::Request.new(env)
      req.params.each { |k, v| req.session[k.to_sym] = v }
      [ 200, {}, [ "ok" ] ]
    }

    post "/testing/set_remember_cookie", to: "testing#set_remember_cookie"
  end

  namespace :auth do
    get    "login",    to: "sessions#new",     as: :login
    delete "logout",   to: "sessions#destroy", as: :logout
    get    ":provider/callback", to: "omniauth_callbacks#create", as: :callback
    get    "failure",  to: "omniauth_callbacks#failure"
  end

  resource :onboarding, only: [] do
    collection do
      get "/", action: :step1, as: :start
      post :step1, action: :create_step1
      post :step2, action: :create_step2
      post :step3, action: :create_step3
      get :complete
    end
  end

  namespace :settings do
    resource :budget, only: [ :show, :update ] do
      member do
        patch :update_region
      end
    end
    resource :data_sources, only: [ :show ]
    resources :api_credentials, only: [ :create, :update, :destroy ] do
      member do
        post :verify
      end
    end
  end

  namespace :api do
    resources :reserve_fund_defaults, only: [ :index ]
  end

  namespace :admin do
    resources :acquisition_tax_rates, only: [ :index, :edit, :update ]
  end

  resources :properties, only: [ :index, :show, :create, :destroy ] do
    collection do
      get  :compare,     to: "properties/comparisons#show"
      get  :bulk_import, to: "properties/bulk_imports#new",    as: :bulk_import
      post :bulk_import, to: "properties/bulk_imports#create"
    end
    member do
      patch :toggle_favorite
    end
    resources :documents, only: [ :create, :destroy ], controller: "properties/documents"
    resource :user_property_settings, only: [ :edit, :update ], controller: "properties/user_property_settings"
    resources :photos, only: [ :create, :destroy ], controller: "properties/photos"
    post "analyses/retry", to: "properties/analysis_retries#create", as: :analysis_retry
    resource :rights_analysis_report, only: [], as: :report, module: :properties do
      resources :tenants, only: [ :show, :edit, :update ]
      get :base_right_date, to: "rights_analysis_reports#show_base_right_date"
      get :edit_base_right_date, to: "rights_analysis_reports#edit_base_right_date"
      patch :base_right_date, to: "rights_analysis_reports#update_base_right_date"
    end
    namespace :inspections do
      resource :start, only: [ :create ], controller: "start"
      resources :tabs, only: [ :edit, :update ], param: :tab_key
      resource :grade, only: [ :show ], controller: "grades"
      resource :source_doc_review, only: [ :update ], controller: "source_doc_reviews"
      resources :results, only: [] do
        resource :resolution, only: [ :update ], controller: "resolutions"
      end
    end
  end

  resources :analyses, only: [ :new, :create ] do
    collection do
      get :prompt
      post :manual
      get :history
    end
  end

  resources :search_results, only: [ :index, :create ] do
    collection do
      delete :clear
    end
    member do
      post :import
      post :inline_import
    end
  end

  get "/search", to: "search_results#index", as: :search

  resource :manual, only: [ :show ]

  get "/terms",   to: "legal#terms",   as: :terms
  get "/privacy", to: "legal#privacy", as: :privacy

  patch "/users/toggle_beginner_mode", to: "users#toggle_beginner_mode", as: :toggle_beginner_mode

  scope :eviction_guide, controller: :eviction_guide do
    get "/", action: :guide, as: :eviction_guide_guide
    get "simulator", action: :simulator, as: :eviction_guide_simulator
  end

  namespace :eviction_guide do
    resource :simulation, only: [ :create, :update, :show ]
    get "simulator/prefill", to: "simulations#prefill", as: :simulator_prefill
    get "simulator/select_type", to: "simulations#select_type", as: :simulator_select_type
    get "simulator/question/:code", to: "simulator#question", as: :simulator_question
    get "steps/:code", to: "steps#show", as: :step_detail
    get "branches/:code", to: "branches#show", as: :branch_detail
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
