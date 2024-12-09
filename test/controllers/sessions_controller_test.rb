require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @login_path = "/auth/login"
    @logout_path = "/auth/logout"

    setup_test_data
    setup_cognito_mock
  end

    [
    { email: "", password: "", error: "Email is required" },
    { email: "employee@yahoo.com", password: "", error: "Password is required" },
    { email: "", password: "password", error: "Email is required" },
    { email: "some-email", password: "password", error: "Invalid email address" }
    ].each do |params|
        define_method("test_should_return_bad_request_if_missing_required_parameters_#{params[:email]}_#{params[:password]}") do
            post @login_path, params: { email: params[:email], password: params[:password] }
            assert_response :bad_request
            response_data = JSON.parse(response.body)

            assert_equal params[:error], response_data["error"]
        end
    end

  test "should log in successfully as employee" do
    post @login_path, params: { email: @employee1.email, password: "password" }
    assert_response :ok
    response_data = JSON.parse(response.body)

    assert_equal "mock_access_token", response_data["access_token"]
    assert_equal "mock_refresh_token", response_data["refresh_token"]
    assert_equal @employee1.id, response_data["user"]["id"]
    assert_equal @employee1.first_name, response_data["user"]["first_name"]
    assert_equal @employee1.last_name, response_data["user"]["last_name"]
    assert_equal @employee1.email, response_data["user"]["email"]
    assert_equal @employee1.telephone, response_data["user"]["telephone"]
    assert_equal @employee1.branch.id, response_data["user"]["branch"]["id"]
    assert_equal @employee1.area.id, response_data["user"]["area"]["id"]
    assert_equal @employee1.contract_code, response_data["user"]["contract_code"]
    assert_equal @employee1.tax_code, response_data["user"]["tax_code"]
    assert_equal @employee1.date_of_birth.strftime(Constants::DATE_FORMAT), response_data["user"]["date_of_birth"]
    assert_equal @employee1.contract_start_date.strftime(Constants::DATE_FORMAT), response_data["user"]["contract_start_date"]
    assert_equal @employee1.contract_end_date.strftime(Constants::DATE_FORMAT), response_data["user"]["contract_end_date"]
    assert_equal @employee1.created_at.strftime(Constants::DATETIME_FORMAT), response_data["user"]["created_at"]
    assert_equal @employee1.updated_at.strftime(Constants::DATETIME_FORMAT), response_data["user"]["updated_at"]
    assert_equal "Logged in successfully", response_data["message"]
  end

  [
  { user_type: "manager" },
  { user_type: "director" },
  { user_type: "super_admin" }
  ].each do |user_info|
        define_method("test_should_log_in_successfully_as_#{user_info[:user_type]}") do
            user_type = user_info[:user_type]
            if user_type == "manager"
                user = @manager
            elsif user_type == "director"
                user = @director
            else
                user = @super_admin
            end

            post @login_path, params: { email: user.email, password: "password", user_type: user_type }
            assert_response :ok

            response_data = JSON.parse(response.body)

            assert_equal "mock_access_token", response_data["access_token"]
            assert_equal "mock_refresh_token", response_data["refresh_token"]
            assert_equal user.id, response_data["user"]["id"]
            assert_equal user.first_name, response_data["user"]["first_name"]
            assert_equal user.last_name, response_data["user"]["last_name"]
            assert_equal user.email, response_data["user"]["email"]
            assert_equal user.telephone, response_data["user"]["telephone"]

            if user_type == "manager"
                assert_equal user.branch.id, response_data["user"]["branch"]["id"]
                assert_equal user.area.id, response_data["user"]["area"]["id"]
            elsif user_type == "director"
                assert_equal user.branch.id, response_data["user"]["branch"]["id"]
                assert_nil response_data["user"]["area"]
            else
                assert_nil response_data["user"]["branch"]
                assert_nil response_data["user"]["area"]
            end

            assert_equal user.created_at.strftime(Constants::DATETIME_FORMAT), response_data["user"]["created_at"]
            assert_equal user.updated_at.strftime(Constants::DATETIME_FORMAT), response_data["user"]["updated_at"]
            assert_equal "Logged in successfully", response_data["message"]
        end
    end

    test "should return error if account does not exist" do
        post @login_path, params: { email: "nonexistent@gmail.com", password: "password" }
        assert_response :unauthorized
        response_data = JSON.parse(response.body)

        assert_equal "Account does not exist", response_data["error"]
    end

    test "should return error if user needs to respond to challenge" do
        @mock_cognito_service.stubs(:authenticate).returns(
        Aws::CognitoIdentityProvider::Types::InitiateAuthResponse.new(
                challenge_name: "NEW_PASSWORD_REQUIRED",
                session: "mock_session",
            )
        )

        post @login_path, params: { email: @employee1.email, password: "password" }
        assert_response :unauthorized
        response_data = JSON.parse(response.body)

        assert_equal "User needs to respond to challenge: NEW_PASSWORD_REQUIRED", response_data["error"]
        assert_equal "mock_session", response_data["session_code"]
        assert_equal "NEW_PASSWORD_REQUIRED", response_data["challenge_name"]
    end

    # Helper method to simulate Cognito errors and test the response
    def simulate_cognito_error(error_type, error_message, error_code)
        @mock_cognito_service.stubs(:authenticate).raises(error_type.new(error_message, error_code))

        post @login_path, params: { email: @manager.email, password: "password" }

        assert_response :unauthorized
        response_data = JSON.parse(@response.body)
        assert_equal error_message, response_data["error"]
    end

    test "should handle various Cognito errors gracefully" do
        simulate_cognito_error(Aws::CognitoIdentityProvider::Errors::UserNotFoundException, "Account does not exist", "UserNotFound")
        simulate_cognito_error(Aws::CognitoIdentityProvider::Errors::NotAuthorizedException, "Invalid email or password", "NotAuthorized")
        simulate_cognito_error(Aws::CognitoIdentityProvider::Errors::UserNotConfirmedException, "Account not confirmed", "UserNotConfirmed")
        simulate_cognito_error(Aws::CognitoIdentityProvider::Errors::InvalidPasswordException, "Invalid password", "InvalidPassword")
    end

    test "should log out successfully" do
        delete @logout_path, headers: { Authorization: "Bearer mock_access_token" }
        assert_response :ok
        response_data = JSON.parse(response.body)

        assert_equal "Logged out successfully", response_data["message"]
    end

    test "should handle missing Authorization header on logout" do
        delete @logout_path
        assert_response :unauthorized
        response_data = JSON.parse(response.body)

        assert_equal "Missing Authorization Header", response_data["message"]
    end

    test "should handle Cognito revoke token errors gracefully" do
        @mock_cognito_service.stubs(:revoke_token).raises(Aws::CognitoIdentityProvider::Errors::ServiceError.new(nil, "An error occurred"))

        delete @logout_path, headers: { Authorization: "Bearer mock_access_token" }
        assert_response :internal_server_error
        response_data = JSON.parse(response.body)

        assert_equal "An error occurred while logging out, please try again", response_data["error"]
    end
end
