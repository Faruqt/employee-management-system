require "test_helper"

class PasswordsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @set_new_password_path = "/auth/password/set"
    @request_password_reset_path = "/auth/password/forgot"
    @reset_password_path = "/auth/password/reset"
    @admin_reset_password_path = "/auth/admin/password/reset"
    @change_password_path = "/auth/password/change"

    setup_test_data
    setup_cognito_mock
  end

  def get_user_by_user_type(user_type)
    case user_type
    when "employee"
      @employee1
    when "manager"
      @manager1
    when "director"
      @director1
    when "super_admin"
      @super_admin
    end
  end

    [
    { email: "", new_password: "", session_code: "", error: "Email, new password, and session code are required" },
    { email: "employee@yahoo.com", new_password: "", session_code: "", error: "Email, new password, and session code are required" },
    { email: "", new_password: "password", session_code: "12345", error: "Email, new password, and session code are required" },
    { email: "some-email", new_password: "password", session_code: "12345", error: "The email provided is invalid. Please provide a valid email address." }
    ].each do |params|
      define_method("test_should_return_bad_request_if_missing_required_parameters_#{params[:email]}_#{params[:new_password]}_#{params[:session_code]}") do
        post @set_new_password_path, params: { email: params[:email], new_password: params[:new_password], session_code: params[:session_code] }
        assert_response :bad_request
        response_data = JSON.parse(response.body)

        assert_equal params[:error],  response_data["error"]
        end
    end

  test "should set new password successfully" do
    post @set_new_password_path, params: { email: @employee1.email, new_password: "new_password", session_code: "12345" }
    assert_response :ok
    response_data = JSON.parse(response.body)

    assert_equal "Password set successfully", response_data["message"]
  end

      [
    { email: "",  error: "Email is required" },
    { email: "some-email", error: "The email provided is invalid. Please provide a valid email address." }
    ].each do |params|
      define_method("test_should_return_bad_request_if_missing_required_parameters_#{params[:email]}") do
        post @request_password_reset_path, params: { email: params[:email] }
        assert_response :bad_request
        response_data = JSON.parse(response.body)

        assert_equal params[:error],  response_data["error"]
        end
    end

    test "Should_request_password_reset_successfully" do
      post @request_password_reset_path, params: { email: @employee1.email }
      assert_response :ok
      response_data = JSON.parse(response.body)

      assert_equal "Password reset code sent successfully to #{@employee1.email}", response_data["message"]
    end

        [
    { email: "", new_password: "", confirmation_code: "", error: "Email, new password, and confirmation code are required" },
    { email: "employee@yahoo.com", new_password: "", confirmation_code: "", error: "Email, new password, and confirmation code are required" },
    { email: "", new_password: "password", confirmation_code: "12345", error: "Email, new password, and confirmation code are required" },
    { email: "some-email", new_password: "password", confirmation_code: "12345", error: "The email provided is invalid. Please provide a valid email address." }
    ].each do |params|
      define_method("test_should_return_bad_request_if_missing_required_parameters_#{params[:email]}_#{params[:new_password]}_#{params[:confirmation_code]}") do
        post @reset_password_path, params: { email: params[:email], new_password: params[:new_password], confirmation_code: params[:confirmation_code] }
        assert_response :bad_request
        response_data = JSON.parse(response.body)

        assert_equal params[:error],  response_data["error"]
        end
    end

    test "should_reset_password_successfully" do
      post @reset_password_path, params: { email: @employee1.email, new_password: "new_password", confirmation_code: "12345" }
      assert_response :ok
      response_data = JSON.parse(response.body)

      assert_equal "Password reset successfully", response_data["message"]
    end

            [
    { email: "", new_password: "", user_type: "manager", error: "Email and new password are required" },
    { email: "employee@yahoo.com", new_password: "password", user_type: "", error: "User type is required" },
    { email: "john", new_password: "password", user_type: "some-user-type", error: "The user type you provided is invalid. Please provide a valid user type: 'employee', 'manager', or 'director'." },
    { email: "some-email", new_password: "some-password", user_type: "director", error: "The email provided is invalid. Please provide a valid email address." }
    ].each do |params|
      define_method("test_should_return_bad_request_if_missing_required_parameters_#{params[:email]}_#{params[:new_password]}_#{params[:user_type]}") do
        setup_cognito_mock_for_authentication(@manager1.email)
        session = setup_authenticated_session(@manager1)

        # Get the access token from the session data
        access_token = session[:access_token]

        post @admin_reset_password_path, params: { email: params[:email], new_password: params[:new_password], user_type: params[:user_type] }, headers: { "Authorization" => "Bearer #{access_token}" }
        assert_response :bad_request
        response_data = JSON.parse(response.body)

        assert_equal params[:error],  response_data["error"]
        end
    end

    test "employee cannot use the admin reset password endpoint" do
      setup_cognito_mock_for_authentication(@employee1.email)
      session = setup_authenticated_session(@employee1)

      # Get the access token from the session data
      access_token = session[:access_token]

      post @admin_reset_password_path, params: { email: "johnQ@gmail.co", new_password: "new_password", user_type: "manager" }, headers: { "Authorization" => "Bearer #{access_token}" }

      assert_response :unauthorized
      response_data = JSON.parse(response.body)

      assert_equal "You are not authorized to perform this action", response_data["message"]
    end

    [
    { user_type: "manager", error: "You are not authorized to reset the password of a manager" },
    { user_type: "director", error: "You are not authorized to reset the password of a director" },
    { user_type: "super_admin", error: "The user type you provided is invalid. Please provide a valid user type: 'employee', 'manager', or 'director'." }
    ].each do |params|
      define_method("test_manager_cannot_reset_password_for_#{params[:user_type]}") do
        setup_cognito_mock_for_authentication(@manager1.email)
        session = setup_authenticated_session(@manager1)

        # Get the access token from the session data
        access_token = session[:access_token]

        user_type = params[:user_type]

        user = get_user_by_user_type(user_type)

        post @admin_reset_password_path, params: { email: user.email, new_password: "new_password", user_type: user_type }, headers: { "Authorization" => "Bearer #{access_token}" }
        if user_type == "super_admin"
          assert_response :bad_request
        else
          assert_response :unauthorized
        end

        response_data = JSON.parse(response.body)

        assert_equal params[:error], response_data["error"]
        end
      end

    [
    { user_type: "director", error: "You are not authorized to reset the password of a director" },
    { user_type: "super_admin", error: "The user type you provided is invalid. Please provide a valid user type: 'employee', 'manager', or 'director'." }
    ].each do |params|
      define_method("test_director_cannot_reset_password_for_#{params[:user_type]}") do
        setup_cognito_mock_for_authentication(@director1.email)
        session = setup_authenticated_session(@director1)

        # Get the access token from the session data
        access_token = session[:access_token]

        user_type = params[:user_type]

        user = get_user_by_user_type(user_type)

        post @admin_reset_password_path, params: { email: user.email, new_password: "new_password", user_type: user_type }, headers: { "Authorization" => "Bearer #{access_token}" }
        if user_type == "super_admin"
          assert_response :bad_request
        else
          assert_response :unauthorized
        end

        response_data = JSON.parse(response.body)

        assert_equal params[:error], response_data["error"]
        end
      end

          [
    { user_type: "manager" },
    { user_type: "director" },
    { user_type: "super_admin" }
    ].each do |params|
      define_method("test_#{params[:user_type]}_can_reset_password_for_employee") do
        user_type = params[:user_type]
        user = get_user_by_user_type(user_type)

        setup_cognito_mock_for_authentication(user.email)
        session = setup_authenticated_session(user)

        # Get the access token from the session data
        access_token = session[:access_token]

        post @admin_reset_password_path, params: { email: @employee1.email, new_password: "new_password", user_type: "employee" }, headers: { "Authorization" => "Bearer #{access_token}" }
        assert_response :ok
        response_data = JSON.parse(response.body)

        assert_equal "Password reset for #{@employee1.email} was successful", response_data["message"]
      end
    end

          [
    { user_type: "director" },
    { user_type: "super_admin" }
    ].each do |params|
      define_method("test_#{params[:user_type]}_can_reset_password_for_managers") do
        user_type = params[:user_type]
        user = get_user_by_user_type(user_type)

        setup_cognito_mock_for_authentication(user.email)
        session = setup_authenticated_session(user)

        # Get the access token from the session data
        access_token = session[:access_token]

        post @admin_reset_password_path, params: { email: @manager1.email, new_password: "new_password", user_type: "employee" }, headers: { "Authorization" => "Bearer #{access_token}" }
        assert_response :ok
        response_data = JSON.parse(response.body)

        assert_equal "Password reset for #{@manager1.email} was successful", response_data["message"]
      end
    end

    test "super admin can reset password for directors" do
      setup_cognito_mock_for_authentication(@super_admin.email)
      session = setup_authenticated_session(@super_admin)

      # Get the access token from the session data
      access_token = session[:access_token]

      post @admin_reset_password_path, params: { email: @director1.email, new_password: "new_password", user_type: "employee" }, headers: { "Authorization" => "Bearer #{access_token}" }
      assert_response :ok
      response_data = JSON.parse(response.body)

      assert_equal "Password reset for #{@director1.email} was successful", response_data["message"]
    end

              [
    { user_type: "employee" },
    { user_type: "manager" },
    { user_type: "director" },
    { user_type: "super_admin" }
    ].each do |params|
        define_method("test_should_return_bad_request_if_missing_required_parameters_#{params[:user_type]}") do
        user_type = params[:user_type]
        user = get_user_by_user_type(user_type)

        setup_cognito_mock_for_authentication(user.email)
        session = setup_authenticated_session(user)

        # Get the access token from the session data
        access_token = session[:access_token]

        post @change_password_path, params: { old_password: "", new_password: "new_password" }, headers: { "Authorization" => "Bearer #{access_token}" }
        assert_response :bad_request
        response_data = JSON.parse(response.body)

        assert_equal "Old password and new password are required",  response_data["error"]
        end
    end

                [
    { user_type: "employee" },
    { user_type: "manager" },
    { user_type: "director" },
    { user_type: "super_admin" }
    ].each do |params|
        define_method("test_should_return_not_authorised_without_authentication_#{params[:user_type]}") do
        user_type = params[:user_type]
        user = get_user_by_user_type(user_type)

        post @change_password_path, params: { old_password: "password", new_password: "new_password" }

        assert_response :unauthorized

        response_data = JSON.parse(response.body)

        assert_equal "Missing Authorization Header", response_data["message"]
        end
    end


          [
    { user_type: "employee" },
    { user_type: "manager" },
    { user_type: "director" },
    { user_type: "super_admin" }
    ].each do |params|
      define_method("test_#{params[:user_type]}_can_change_their_password") do
          user_type = params[:user_type]
          user = get_user_by_user_type(user_type)

          setup_cognito_mock_for_authentication(user.email)
          session = setup_authenticated_session(user)

          # Get the access token from the session data
          access_token = session[:access_token]

          post @change_password_path, params: { old_password: "password", new_password: "new_password" }, headers: { "Authorization" => "Bearer #{access_token}" }
          assert_response :ok
          response_data = JSON.parse(response.body)

          assert_equal "Password changed successfully", response_data["message"]
        end
      end
end
