class RegistrationsController < ApplicationController
  # Check if email and user_type are present before trying to log in
  before_action :check_params, only: [ :create ]

  # Set up the Cognito service
  before_action :set_cognito_service

  # POST /register_user
  def create
    email = params[:email]
    password = Utils::PasswordGenerator.generate_password(6)
    user_type = params[:user_type]

    begin
      # check if user already exists with the email
      if user_type == "employee"
        user = User.find_by(email: email)
      else
        # check the admin table
        user = nil
      end

      # if user
      #   render json: { error: "Account already exists" }, status: :bad_request
      #   return
      # end
    end

    # response
  end

  private
  # Set up the Cognito service for the controller actions
  def set_cognito_service
    @cognito_service = CognitoService.new
  end

  # Ensure email and password are provided
  def check_params
    unless params[:email]
      render json: { error: "Email is required" }, status: :bad_request
      return
    end

    unless params[:email].include?("@")
      render json: { error: "Invalid email address" }, status: :bad_request
      return
    end

    unless params[:user_type].present?
      render json: { error: "User type is required" }, status: :bad_request
      nil
    end
  end

  def handle_cognito_error(error)
    case error.response.error.code
    when "UserNotFoundException"
      render json: { error: "Account does not exist" }, status: :unauthorized
    when "NotAuthorizedException"
      render json: { error: "Invalid email or password" }, status: :unauthorized
    when "UserNotConfirmedException"
      render json: { error: "Account not confirmed" }, status: :unauthorized
    else
      render json: { error: "An error occurred while trying to create your account, please try again" }, status: :internal_server_error
    end
  end
end
