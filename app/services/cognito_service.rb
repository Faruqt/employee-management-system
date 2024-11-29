# app/services/cognito_service.rb
require "aws-sdk-cognitoidentityprovider"

class CognitoService
  def initialize
    @client = Aws::CognitoIdentityProvider::Client.new
    @user_pool_id = ENV["COGNITO_USER_POOL_ID"]
    @app_client_id = ENV["COGNITO_APP_CLIENT_ID"]
    @app_client_secret = ENV["COGNITO_APP_CLIENT_SECRET"]
  end

  # Sign Up a User
  def sign_up(email, password)
    Rails.logger.info("Signing up user with email: #{email}")
    response = @client.sign_up({
      client_id: @app_client_id,
      username: email,
      password: password,
      user_attributes: [
        { name: "email", value: email }
      ],
      secret_hash: generate_secret_hash(email)
    })
    Rails.logger.info("Sign up successful for email: #{email}")
    response
  rescue Aws::CognitoIdentityProvider::Errors::ServiceError => e
    Rails.logger.error("Error signing up user: #{e.message}")
    raise
  end

  # Authenticate a User (Sign In)
  def authenticate(email, password)
    Rails.logger.info("Authenticating user with email: #{email}")
    response = @client.initiate_auth({
      client_id: @app_client_id,
      auth_flow: "USER_PASSWORD_AUTH",
      auth_parameters: {
        "USERNAME" => email,
        "PASSWORD" => password,
        "SECRET_HASH" => generate_secret_hash(email)
      }
    })
    Rails.logger.info("Authentication successful for email: #{email}")
    response
  rescue Aws::CognitoIdentityProvider::Errors::ServiceError => e
    Rails.logger.error("Error authenticating user: #{e.message}")
    raise
  end

  # Forgot Password
  def forgot_password(email)
    Rails.logger.info("Initiating forgot password for email: #{email}")
    response = @client.forgot_password({
      client_id: @app_client_id,
      username: email,
      secret_hash: generate_secret_hash(email)
    })
    Rails.logger.info("Forgot password initiated by email: #{email}")
    response
  rescue Aws::CognitoIdentityProvider::Errors::ServiceError => e
    Rails.logger.error("Error initiating forgot password: #{e.message}")
    raise
  end

  # Confirm New Password
  def confirm_forgot_password(email, confirmation_code, new_password)
    Rails.logger.info("Confirming forgot password for email: #{email}")
    response = @client.confirm_forgot_password({
      client_id: @app_client_id,
      username: email,
      confirmation_code: confirmation_code,
      password: new_password,
      secret_hash: generate_secret_hash(email)
    })
    Rails.logger.info("Forgot password confirmed for email: #{email}")
    response
  rescue Aws::CognitoIdentityProvider::Errors::ServiceError => e
    Rails.logger.error("Error confirming forgot password: #{e.message}")
    raise
  end

  private

  def generate_secret_hash(username)
    data = username + @app_client_id
    digest = OpenSSL::Digest.new("sha256")
    hmac = OpenSSL::HMAC.digest(digest, @app_client_secret, data)
    Base64.encode64(hmac).strip
  end
end