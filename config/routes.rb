Rails.application.routes.draw do
  resources :tron_wallets
  resources :bet_records
  resources :bots
  resources :members do
    member do
      post :start_bot
      post :stop_bot
      post :paused_bot
      post :reboot_bot
    end
  end
  resources :strategies
  # devise_for :admins

  get "home/map"
  get "home/outside"
  get "home/strategy"
  # devise_for :admins
  devise_for :admins, controllers: {
    sessions: "admins/sessions",
    registrations: "admins/registrations",
    passwords: "admins/passwords",
    confirmations: "admins/confirmations",
    unlocks: "admins/unlocks"
  }
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "home#index"
end
