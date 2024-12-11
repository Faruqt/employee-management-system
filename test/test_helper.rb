ENV["RAILS_ENV"] ||= "test"
ENV["AWS_REGION"] = "some-region"
ENV["S3_USER_BUCKET_URL"] = "https://some-bucket-url"
require_relative "../config/environment"
require "rails/test_help"
require "mocha/minitest"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    def setup_cognito_mock
      # Create a mock of CognitoService
      @mock_cognito_service = mock("CognitoService")

      # Stub the register_user method to return a successful response
      @mock_cognito_service.stubs(:register_user).returns(true)

      # Stub the authenticate method to return a successful response
      @mock_cognito_service.stubs(:authenticate).returns(
        Aws::CognitoIdentityProvider::Types::InitiateAuthResponse.new(
          authentication_result: Aws::CognitoIdentityProvider::Types::AuthenticationResultType.new(
            access_token: "mock_access_token",
            refresh_token: "mock_refresh_token"
          )
        )
      )

      # Stub the get user method to return a successful response
      @mock_cognito_service.stubs(:get_user).returns(
        Aws::CognitoIdentityProvider::Types::GetUserResponse.new(
          username: "mock_user_id",
          user_attributes: [
            Aws::CognitoIdentityProvider::Types::AttributeType.new(name: "email", value: "some-email")
          ]
        )
      )

      # Stub the refresh token method to return a successful response
      @mock_cognito_service.stubs(:refresh_token).returns(
        Aws::CognitoIdentityProvider::Types::InitiateAuthResponse.new(
          authentication_result: Aws::CognitoIdentityProvider::Types::AuthenticationResultType.new(
            access_token: "mock_new_access_token",
            refresh_token: "mock_refresh_token",
          )
        )
      )

      # Stub the logout method to return a successful response
      @mock_cognito_service.stubs(:revoke_token).returns(true)

      # Stub the set_new_password method to return a successful response
      @mock_cognito_service.stubs(:set_new_password).returns(true)

      # stub the verify email method to return a successful response
      @mock_cognito_service.stubs(:verify_email).returns(true)

      # stub the request_password_reset method to return a successful response
      @mock_cognito_service.stubs(:request_password_reset).returns(true)

      # stub the reset password method to return a successful response
      @mock_cognito_service.stubs(:reset_password).returns(true)

      # stub the admin set password method to return a successful response
      @mock_cognito_service.stubs(:admin_set_password).returns(true)

      # stub the change password method to return a successful response
      @mock_cognito_service.stubs(:change_password).returns(true)

      # Mock the CognitoService initialization to return the mock object
      CognitoService.stubs(:new).returns(@mock_cognito_service)
    end

    def setup_cognito_mock_for_authentication(email)
      # Mock the Cognito Identity Provider client
      @mock_cognito_client = mock("Aws::CognitoIdentityProvider::Client")

      # Stub the get_user method to simulate a successful response
      @mock_cognito_client.stubs(:get_user).returns(
        Aws::CognitoIdentityProvider::Types::GetUserResponse.new(
          username: "mock_username",
          user_attributes: [
            Aws::CognitoIdentityProvider::Types::AttributeType.new(name: "email", value: email)
          ]
        )
      )

      # Inject the mock into your app's AWS client
      Aws::CognitoIdentityProvider::Client.stubs(:new).returns(@mock_cognito_client)
    end

    def setup_s3_mock_for_upload
      # Create a mock of S3 client
      @mock_s3_client = mock("FileUploadService")

      # Stub the put_object method to return a successful response
      @mock_s3_client.stubs(:upload_file).returns(true)

      # Mock the FileUploadService initialization to return the mock object
      FileUploadService.stubs(:new).returns(@mock_s3_client)
    end

    def setup_test_data
      # Create test data
      @org = Organization.create!(name: "Organization One", address: "Address One")
      @branch = Branch.create!(name: "Branch One", address: "Branch Address One", organization: @org)
      @area = Area.create!(name: "Area One", color: "Color One")
      @branch.areas << @area
      @manager = Admin.create!(first_name: "John", last_name: "Doe", email: "test_manager_one@gmail.co", telephone: "123456789", is_manager: true, branch: @branch, area: @area)
      @role = Role.create!(name: "Role One", symbol: "Role One Symbol", area_id: @area.id)

      @director = Admin.create!(first_name: "Jane", last_name: "Doe", email: "test_director_one@gmail.co", telephone: "123456789", is_director: true, branch: @branch)
      @super_admin = Admin.create!(first_name: "Super", last_name: "Admin", email: "test_super_one@gmail.co", telephone: "123456789", is_super_admin: true)
      @employee1 = Employee.create!(first_name: "John", last_name: "Doe", email: "test_employee_one@gmail.co", telephone: "123456789", branch: @branch, area: @area, contract_code: "123456", tax_code: "654321", date_of_birth: "1990-01-01", contract_start_date: "2021-01-01", contract_end_date: "2022-01-01")
    end

    def setup_authenticated_session(user)
      # Create a session for the user by simulating a successful login
      @mock_cognito_service.stubs(:authenticate).returns(
        Aws::CognitoIdentityProvider::Types::InitiateAuthResponse.new(
          authentication_result: Aws::CognitoIdentityProvider::Types::AuthenticationResultType.new(
            access_token: "mock_access_token",
            refresh_token: "mock_refresh_token"
          )
        )
      )

      post "/auth/login", params: { email: user.email, password: "password" }
      assert_response :ok
      response_data = ::JSON.parse(response.body)

      # Return the user and the tokens
      { user: user, access_token: response_data["access_token"], refresh_token: response_data["refresh_token"] }
    end

    # Add more helper methods to be used by all tests here...
  end
end
