# app/services/cognito_service.rb
require "aws-sdk-cognitoidentityprovider"

class CognitoService
  def initialize
    @client = Aws::CognitoIdentityProvider::Client.new
    @user_pool_id = ENV["COGNITO_USER_POOL_ID"]
    @app_client_id = ENV["COGNITO_APP_CLIENT_ID"]
    @app_client_secret = ENV["COGNITO_APP_CLIENT_SECRET"]
  end

  # Get a User
  def get_user(access_token)
    Rails.logger.info("Getting user with access token: #{access_token}")

    response = @client.get_user({
      access_token: access_token
    })

    Rails.logger.info("User retrieved successfully with access token: #{access_token}")
    response
  rescue Aws::CognitoIdentityProvider::Errors::ServiceError => e
    Rails.logger.error("Error getting user: #{e.message}")
    raise
  end

  # Sign Up a User
  def register_user(email, password)
    Rails.logger.info("Attempting to create user with email: #{email}")
    # Create the user in Cognito
    response = @client.admin_create_user({
        user_pool_id: @user_pool_id,
        username: email,
        temporary_password: password,
        user_attributes: [
            {
                name: "email",
                value: email
            }
        ]
    })

    Rails.logger.info("Sign up on cognito successful for email: #{email}}")

    response
    rescue Aws::CognitoIdentityProvider::Errors::ServiceError => e
      Rails.logger.error("Error signing up user with email: #{email}. Error: #{e.message}")
      raise e
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

  # Refresh Token
  def refresh_token(refresh_token, user_id)
    response = @client.initiate_auth({
      client_id: @app_client_id,
      auth_flow: "REFRESH_TOKEN_AUTH",
      auth_parameters: {
        "REFRESH_TOKEN" => refresh_token,
        "SECRET_HASH" => generate_secret_hash(user_id)
      }
    })

    Rails.logger.info("Token refreshed successfully")
    response
  rescue Aws::CognitoIdentityProvider::Errors::ServiceError => e
    Rails.logger.error("Error refreshing token: #{e.message}")
    raise
  end

  # Set new password
  def set_new_password(email, password, session)
    Rails.logger.info("Setting new password for email: #{email}")

    response = @client.respond_to_auth_challenge({
      client_id: @app_client_id,
      challenge_name: "NEW_PASSWORD_REQUIRED",
      session: session,
      challenge_responses: {
        "USERNAME" => email,
        "NEW_PASSWORD" => password,
        "SECRET_HASH"=> generate_secret_hash(email),
        "USER_ATTRIBUTES" => '{"email": "' + email + '"}'
      }
    })

    Rails.logger.info("New password set for email: #{email}")
    response
  rescue Aws::CognitoIdentityProvider::Errors::ServiceError => e
    Rails.logger.error("Error setting new password: #{e.message}")
    raise
  end

  # Admin Set Password
  def admin_set_password(email, password)
    Rails.logger.info("Admin setting password for email: #{email}")

    response = @client.admin_set_user_password({
      user_pool_id: @user_pool_id,
      username: email,
      password: password,
      permanent: true
    })

    Rails.logger.info("Password set for email: #{email}")
    response
  rescue Aws::CognitoIdentityProvider::Errors::ServiceError => e
    Rails.logger.error("Error setting password: #{e.message}")
    raise
  end

  # Verify the user's email
  def verify_email(email)
    Rails.logger.info("Verifying email for email: #{email}")
    response = @client.admin_update_user_attributes({
      user_pool_id: @user_pool_id,
      username: email,
      user_attributes: [
        { "name": "email_verified", "value": "true" }
      ]
    })
    Rails.logger.info("Email verified for email: #{email}")
    response
  rescue Aws::CognitoIdentityProvider::Errors::ServiceError => e
    Rails.logger.error("Error verifying email: #{e.message}")
    raise
  end

  # Request Password Reset
  def request_password_reset(email)
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
  def reset_password(email, new_password, confirmation_code)
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

  # Change Password
  def change_password(access_token, previous_password, new_password)
    Rails.logger.info("Changing password for user with access token: #{access_token}")
    response = @client.change_password({
      previous_password: previous_password,
      proposed_password: new_password,
      access_token: access_token
    })

    Rails.logger.info("Password changed successfully for user with access token: #{access_token}")
    response
  rescue Aws::CognitoIdentityProvider::Errors::ServiceError => e
    Rails.logger.error("Error changing password: #{e.message}")
    raise
  end

  # Revoke Token
  def revoke_token(access_token)
    response = @client.global_sign_out({
        access_token: access_token
    })
    Rails.logger.info("Token revoked successfully")
    response
  rescue Aws::CognitoIdentityProvider::Errors::ServiceError => e
    Rails.logger.error("Error revoking token: #{e.message}")
    raise
  end

  # Delete User
  def delete_user(email)
    Rails.logger.info("Deleting user with email: #{email}")

    response = @client.admin_delete_user({
      user_pool_id: @user_pool_id,
      username: email
    })

    Rails.logger.info("User deleted successfully with email: #{email}")
    response
  rescue Aws::CognitoIdentityProvider::Errors::ServiceError => e
    Rails.logger.error("Error deleting user: #{e.message}")
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
