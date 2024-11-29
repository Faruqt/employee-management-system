module AccessRequired
  extend ActiveSupport::Concern

  AWS_COGNITO_REGION = ENV["AWS_COGNITO_REGION"]
  AWS_COGNITO_USER_POOL_ID = ENV["AWS_COGNITO_USER_POOL_ID"]
  AWS_COGNITO_APP_CLIENT_ID = ENV["AWS_COGNITO_APP_CLIENT_ID"]

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

    # Call to authenticate user with the token
    response, error = get_current_user(access_token)

    if error
      render json: response, status: :unauthorized
      return
    end

    # Store the authenticated user in an instance variable (e.g., @current_user)
    @current_user = response
  end

  def get_current_user(access_token)
    # Call Cognito's public keys and validate the JWT token
    jwks_url = "https://cognito-idp.#{AWS_COGNITO_REGION}.amazonaws.com/#{AWS_COGNITO_USER_POOL_ID}/.well-known/jwks.json"
    jwks = JSON.parse(Net::HTTP.get(URI(jwks_url)))["keys"]

    # Decode JWT and find the matching RSA key
    unverified_header = JWT.decode(access_token, nil, false).first
    rsa_key = find_rsa_key(jwks, unverified_header["kid"])

    if rsa_key.blank?
      return { message: "Unable to find appropriate key" }, 401
    end

    # Decode the token and validate it
    begin
      payload = JWT.decode(
        access_token,
        rsa_key,
        true,
        { algorithm: "RS256", aud: AWS_COGNITO_APP_CLIENT_ID, iss: "https://cognito-idp.#{AWS_COGNITO_REGION}.amazonaws.com/#{AWS_COGNITO_USER_POOL_ID}" }
      ).first

      # Get user info from Cognito
      current_user = { username: payload["username"] }

      # Fetch user attributes using AWS SDK (Cognito)
      client = Aws::CognitoIdentityProvider::Client.new(region: AWS_COGNITO_REGION)
      user = client.get_user({ access_token: access_token, client_id: AWS_COGNITO_APP_CLIENT_ID }).user

      user.attributes.each do |attribute|
        current_user[attribute.name.to_sym] = attribute.value if attribute.name == "email"
      end

      return current_user, nil
    rescue JWT::ExpiredSignatureError => e
        Rails.logger.error("Token has expired: #{e.message}")
      return { message: "Token has expired" }, 401
    rescue JWT::DecodeError, JWT::InvalidIssuerError, JWT::InvalidAudError => e
        Rails.logger.error("Invalid token: #{e.message}")
      return { message: "Invalid token" }, 401
    rescue StandardError => e
      Rails.logger.error("Error decoding token: #{e.message}")
      return { message: "An error occurred while decoding the token" }, 500
    end
  end

  def find_rsa_key(jwks, kid)
    jwks.find { |key| key["kid"] == kid }
  end
end
