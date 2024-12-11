require "test_helper"

class ProfileControllerTest < ActionDispatch::IntegrationTest
  def setup
    @profile_path = "/profile"

    setup_test_data
    setup_cognito_mock
  end


  def get_user_by_user_type(user_type)
    case user_type
    when "employee"
      @employee1
    when "manager"
      @manager
    when "director"
      @director
  end

  def authenticate_user(user)
    setup_cognito_mock_for_authentication(user.email)

    session = setup_authenticated_session(user)

    access_token = session[:access_token]

    access_token
  end

  [
    {user_type: "employee"},
    { user_type: "manager"},
    { user_type: "director"},
  ].each do |params|
    define_method("test_should_return_unauthorized_if_no_access_token_and_user_type_is_provided_#{params[:user_type]}") do
      get @profile_path
      assert_response :unauthorized
      response_data = JSON.parse(response.body)
      assert_equal "Missing Authorization Header", response_data["message"]
    end
  end

  [
    {user_type: "employee"},
    { user_type: "manager"},
    { user_type: "director"},
  ].each do |params|
    define_method("test_should_return_error_if_user_type_is_not_provided_#{params[:user_type]}") do
      user_type = params[:user_type]
      user = get_user_by_user_type(user_type)
      access_token = authenticate_user(user)
      get @profile_path, headers: { "Authorization" => "Bearer #{access_token}" }
      assert_response :bad_request
      response_data = JSON.parse(response.body)
      assert_equal "User type is required", response_data["error"]
    end
  end

  [
    {user_type: "employee"},
    { user_type: "manager"},
    { user_type: "director"},
  ].each do |params|
      define_method("test_should_return_error_if_user_type_is_invalid_#{params[:user_type]}") do
      user_type = params[:user_type]
      user = get_user_by_user_type(user_type)
      access_token = authenticate_user(user)
      get @profile_path, headers: { "Authorization" => "Bearer #{access_token}" }, params: { user_type: "invalid" }
      assert_response :bad_request
      response_data = JSON.parse(response.body)
      assert_equal "The user type you provided is invalid. Please provide a valid user type: 'employee', 'manager', or 'director'.", response_data["error"]
    end
  end

    [
    {user_type: "employee"},
    { user_type: "manager"},
    { user_type: "director"},
  ].each do |params|
    define_method("test_should_return_user_profile_#{params[:user_type]}") do
      user_type = params[:user_type]
      user = get_user_by_user_type(user_type)
      access_token = authenticate_user(user)
      get @profile_path, headers: { "Authorization" => "Bearer #{access_token}" }, params: { user_type: user_type }
      assert_response :success
      response_data = JSON.parse(response.body)
      assert_equal user.email, response_data["profile"]["email"]
      assert_equal user.first_name, response_data["profile"]["first_name"]
    end
  end

end
