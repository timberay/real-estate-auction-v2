Rails.application.routes.draw do
  root "home#index"

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
    resource :budget, only: [ :show, :update ]
    resources :budget_snapshots, only: [ :index, :show ] do
      member do
        post :recalculate
      end
      collection do
        get :compare
      end
    end
  end

  namespace :api do
    resources :reserve_fund_defaults, only: [ :index ]
  end

  resources :properties, only: [ :index, :show, :create ] do
    namespace :inspections do
      resource :start, only: [ :create ], controller: "start"
      resources :tabs, only: [ :edit, :update ], param: :tab_key
      resource :grade, only: [ :show ], controller: "grades"
      resource :dividend, only: [ :update ], controller: "dividends"
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
