Rails.application.routes.draw do
  root 'sessions#index'
  
  get 'plex_auth/new', to: 'plex_auth#new', as: :new_plex_auth
  get 'plex_auth/callback', to: 'plex_auth#callback', as: :callback_plex_auth

  resources :votes, only: [:create]

  resources :sessions, only: [:index, :new, :create, :show] do
    resources :votes, only: [:create]
    member do
      get 'join', to: 'sessions#join', as: :join
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
