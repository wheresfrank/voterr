Rails.application.routes.draw do
  root 'sessions#index'

  # Plex Authentication Routes
  scope :plex_auth, controller: :plex_auth do
    get 'new', action: :new, as: :new_plex_auth
    get 'callback', action: :callback, as: :callback_plex_auth
  end

  # Sessions and Voting Routes
  resources :sessions, only: [:index, :new, :create, :show, :destroy] do
    resources :votes, only: [:create]
    resources :voters, only: [:destroy]
  end

  delete 'logout', to: 'sessions#logout', as: :logout

  # Guest Routes (not nested under resources :sessions)
  get 'join', to: 'sessions#join', as: :join_session
  post 'guest_vote', to: 'sessions#guest_vote', as: :guest_vote

  # Guest Session Viewing Route (not nested under resources :sessions)
  get 'guest/:token', to: 'sessions#show_guest', as: :show_guest_session

  # Health Check Route
  get "up", to: "rails/health#show", as: :rails_health_check
end