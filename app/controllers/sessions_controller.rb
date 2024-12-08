class SessionsController < ApplicationController
  # Check if email, password are present before trying to log in
  before_action :check_params, only: [ :create ]
  # Set up the Cognito service
  before_action :set_cognito_service

  # POST /login
  def create
    email = params[:email]
    password = params[:password]

    begin
      user = Employee.find_by(email: email)
      if !user
        user = Admin.find_by(email: email)
      end

      if !user
        render json: { error: "Account does not exist" }, status: :unauthorized
        return
      end

      response = @cognito_service.authenticate(email, password)

      # if the response contains a challenge, the user needs to respond to it
      if response.challenge_name
        render json: { error: "User needs to respond to challenge: #{response.challenge_name}",
        session_code: response.session, challenge_name: response.challenge_name }, status: :unauthorized
        return
      end

      # On successful authentication, return tokens and user info
      access_token = response.authentication_result.access_token
      refresh_token = response.authentication_result.refresh_token
      render json: { access_token: access_token,
                      refresh_token: refresh_token,
                      user: user.public_attributes,
         message: "Logged in successfully" }, status: :ok
    rescue Aws::CognitoIdentityProvider::Errors::ServiceError => e
      Rails.logger.error("Error authenticating user: #{e.message}")
      handle_cognito_error(e)
    rescue StandardError => e
      Rails.logger.error("Unexpected error: #{e.message}")
      render json: { error: "An error occurred while logging in, please try again" }, status: :internal_server_error
    end
  end

  # DELETE /logout
  def destroy
    # check authorization header
    if request.headers["Authorization"].blank?
      render json: { message: "Missing Authorization Header" }, status: :unauthorized
      return
    end

    # get the access token from the header
    access_token = request.headers["Authorization"].split(" ")
    # check length of access token
    access_token = access_token.length > 1 ? access_token[1] : nil
    unless access_token
      render json: { message: "Missing Authorization Header" }, status: :unauthorized
      return
    end

    begin
      # revoke the token
      @cognito_service.revoke_token(access_token)
      render json: { message: "Logged out successfully" }, status: :ok
    rescue Aws::CognitoIdentityProvider::Errors::ServiceError => e
      Rails.logger.error("Error revoking token: #{e.message}")
      render json: { error: "An error occurred while logging out, please try again" }, status: :internal_server_error
      nil
    rescue StandardError => e
      Rails.logger.error("Unexpected error: #{e.message}")
      render json: { error: "An error occurred while logging out, please try again" }, status: :internal_server_error
    end
  end

  private
  # Set up the Cognito service for the controller actions
  def set_cognito_service
    @cognito_service = CognitoService.new
  end

  # Ensure email and password are provided
  def check_params

    unless params[:email] && params[:password]
      render json: { error: "Email and password are required" }, status: :bad_request
      return
    end

    unless params[:email].present?
      render json: { error: "Email is required" }, status: :bad_request
      return
    end

    unless params[:password].present?
      render json: { error: "Password is required" }, status: :bad_request
      return
    end

    unless Utils::EmailValidator.valid?(params[:email])
      render json: { error: "Invalid email address" }, status: :bad_request
      return
    end
  end

  def handle_cognito_error(error)
    # Log the error for debugging purposes
    Rails.logger.error("Cognito error: #{error.inspect}")

    # Check for specific AWS Cognito error classes
    case error
    when Aws::CognitoIdentityProvider::Errors::UserNotFoundException
      render json: { error: "Account does not exist" }, status: :unauthorized
    when Aws::CognitoIdentityProvider::Errors::NotAuthorizedException
      render json: { error: "Invalid email or password" }, status: :unauthorized
    when Aws::CognitoIdentityProvider::Errors::UserNotConfirmedException
      render json: { error: "Account not confirmed" }, status: :unauthorized
    when Aws::CognitoIdentityProvider::Errors::InvalidPasswordException
      render json: { error: "Invalid password" }, status: :unauthorized
    else
      # For any other unexpected Cognito error, or if error is not related to Cognito
      render json: { error: "An error occurred while logging in, please try again" }, status: :internal_server_error
    end
  end
end
