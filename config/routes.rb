Rails.application.routes.draw do
  devise_for :users, skip: :all
  root "admin/translations#new"
  get "/login", to: "sessions#new", as: :login
  post "/login", to: "sessions#create"
  delete "/logout", to: "sessions#destroy", as: :logout
  resource :reauthentication, only: %i[new create]
  resource :preferences, only: :update

  namespace :admin do
    get "dashboard", to: "dashboard#index", as: :dashboard
    get "help", to: "help#index", as: :help
    resources :glossary_entries, only: %i[index new create edit update destroy]
    get "security", to: "security#index", as: :security
    resources :translations, only: %i[index new create show] do
      member { post :refresh_status }
      member { get :progress }
      member { patch :prefer }
      member { get :export }
    end
    namespace :settings do
      resource :inference, only: :show, controller: :inference
      resources :inference_connections, except: %i[show destroy] do
        member { post :check_connection }
      end
      resources :model_deployments, only: :create
      resources :translation_models, only: :update
    end
  end

  # Keep this route last so it never shadows an existing controller action.
  match "*unmatched", to: "errors#not_found", via: :all, format: false
end
