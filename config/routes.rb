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

  resources :properties, only: [ :index, :show, :create, :destroy ] do
    resources :documents, only: [ :create, :destroy ], controller: "properties/documents"
    namespace :inspections do
      resource :start, only: [ :create ], controller: "start"
      resources :tabs, only: [ :edit, :update ], param: :tab_key
      resource :grade, only: [ :show ], controller: "grades"
      resource :dividend, only: [ :update ], controller: "dividends"
      resource :source_doc_review, only: [ :update ], controller: "source_doc_reviews"
    end
  end

  resources :analyses, only: [ :new, :create ] do
    collection do
      get :prompt
      post :manual
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
