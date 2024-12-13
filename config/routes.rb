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

  # Defines the routes for the areas controller using RESTful routes
  resources :areas, only: [ :index, :show, :create, :update, :destroy ]

  # Defines the routes for the roles controller using RESTful routes
  resources :roles, only: [ :index, :show, :create, :update, :destroy ]

  # Defines the routes for the sessions controller
  post "auth/login" => "sessions#create"
  post "auth/refresh_token" => "sessions#refresh_token"
  delete "auth/logout" => "sessions#destroy"

  # Defines the routes for the registration controller
  post "auth/register" => "registrations#create"

  # Defines custom routes for passwords controller
  # User has to set a new password after account creation
  post "auth/password/set", to: "passwords#set_new_password"

  # User can request a password reset
  post "auth/password/forgot", to: "passwords#request_password_reset"

  # User can reset their password
  post "auth/password/reset", to: "passwords#reset_password"

  # User can change their password
  post "auth/password/change", to: "passwords#change_password"

  # Admin can reset a user's password
  post "auth/admin/password/reset", to: "passwords#admin_reset_password"

  # Defines the routes for the profile controller
  get "profile" => "profile#index"

  # Defines the routes for the user management controller
  post "user/toggle_archive_state" => "user_management#toggle_archive_state"
  delete "user/:id" => "user_management#destroy"

  # Catch-all route for undefined paths
  match "*path", to: "application#route_not_found", via: :all
end
