require "aws-sdk-cognitoidentityprovider"

module AccessRequired
  extend ActiveSupport::Concern


  included do
    before_action :authenticate_user!
  end

  private

  def authenticate_user!

    access_token = request.headers["Authorization"]&.split(" ")&.last

    # Check if Authorization header exists
    unless access_token
      render json: { message: "Missing Authorization Header" }, status: :unauthorized
      return
    end

    # Use the Cognito Identity Provider client to validate the token
    client = Aws::CognitoIdentityProvider::Client.new

    begin
      @current_user = {}  # Initialize @current_user as a hash

      # Validate the JWT token against Cognito's user pool
      response = client.get_user({ access_token: access_token })

      @current_user["username"] = response.username
      @current_user["access_token"] = access_token

      # You can also fetch user attributes here, such as email
      response.user_attributes.each do |attribute|
        @current_user[attribute.name] = attribute.value if attribute.name == "email"
      end

    rescue Aws::CognitoIdentityProvider::Errors::ServiceError => e
      Rails.logger.error("Error validating token: #{e.message}")
      error_message = e.message || "Access token is invalid"
      render json: { message: error_message }, status: :unauthorized
      nil
    rescue StandardError => e
      Rails.logger.error("Unexpected error: #{e.message}")
      render json: { error: "An error occurred while validating token, please try again" }, status: :internal_server_error
      nil
    end
  end
end
