Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  # Defines the root path route ("/")
  root "welcome#index"

  # Defines the routes for the organizations controller using RESTful routes
  resources :organizations, only: [ :index, :show, :create, :update, :destroy ]

  # Defines the routes for the branches controller using RESTful routes
  resources :branches, only: [ :index, :show, :create, :update, :destroy ]

  # Defines the routes for the sessions controller
  post "login" => "sessions#create"
  delete "logout" => "sessions#destroy"

  # Defines the routes for the registration controller
  post "register" => "registrations#create"

  # resources :users, only: %i[create show update]
end
