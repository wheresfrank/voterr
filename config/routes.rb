Rails.application.routes.draw do
  root "pages#home"

  get "about", to: "pages#about", as: :about
  get "compare", to: "pages#compare", as: :compare
  get "privacy", to: "pages#privacy", as: :privacy
  get "plex-movie-night", to: redirect("/compare")
  get "faq", to: redirect("/compare")
  get "docs", to: redirect("https://github.com/wheresfrank/voterr")

  get "llms.txt", to: "pages#llms", as: :llms, defaults: { format: :text }
  get "robots.txt", to: "pages#robots", defaults: { format: :text }
  get "sitemap.xml", to: "pages#sitemap", as: :sitemap, defaults: { format: :xml }

  get "login", to: "plex_auth#new", as: :login

  # Plex Authentication Routes
  scope :plex_auth, controller: :plex_auth do
    get "new", action: :new, as: :new_plex_auth
    post "callback", action: :callback, as: :callback_plex_auth
  end

  # Sessions and Voting Routes
  resources :sessions, only: [:index, :create, :show, :destroy] do
    member do
      patch :start_voting
      patch :select_winner
    end
    resources :votes, only: [:create]
    resources :voters, only: [:destroy]
  end

  delete "logout", to: "sessions#logout", as: :logout

  # Guest Routes (not nested under resources :sessions)
  get "join", to: "sessions#join", as: :join_session
  post "guest_vote", to: "sessions#guest_vote", as: :guest_vote

  # Guest Session Viewing Route (not nested under resources :sessions)
  get "guest/:token", to: "sessions#show_guest", as: :show_guest_session

  # Health Check Route
  get "up", to: "rails/health#show", as: :rails_health_check
end
