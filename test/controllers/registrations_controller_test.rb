require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  def setup
    setup_test_data
    setup_cognito_mock
    setup_s3_mock_for_upload

    @register_path = "/auth/register"

    # create additional area
    @area2 = Area.create!(name: "Detached Area Two", color: "Color Two")
  end

  def get_user_by_user_type(user_type)
    case user_type
    when "manager"
      @manager
    when "director"
      @director
    when "super_admin"
      @super_admin
    end
  end

  def authenticate_user(user)
    setup_cognito_mock_for_authentication(user.email)

    session = setup_authenticated_session(user)

    access_token = session[:access_token]

    access_token
  end

  def employee_param(area_id, branch_id, first_name = "John", email = "john_doe@gmail.com")
    {
      first_name: first_name,
      last_name: "Doe",
      email: email,
      telephone: "123456789",
      branch_id: branch_id,
      area_id: area_id,
      contract_code: "123456",
      tax_code: "654321",
      date_of_birth: "1990-01-01",
      contract_start_date: "2021-01-01",
      contract_end_date: "2022-01-01",
      user_type: "employee"
    }
  end

  def admin_param(area_id, branch_id, user_type, first_name = "Johnny", email = "some-admin.gmail.com")
    {
      first_name: first_name,
      last_name: "Admin",
      email: email,
      telephone: "123456789",
      branch_id: branch_id,
      area_id: area_id,
      user_type: user_type
    }
  end

  test "should return unauthorized if user is not logged in" do
    post @register_path, params: admin_param(@area.id, @branch.id, user_type="manager", first_name="Paul", email="some-email")

    assert_response :unauthorized
    response_data = JSON.parse(@response.body)

    assert_equal "Missing Authorization Header", response_data["message"]
  end

  test "should return bad request if missing required parameters" do
    access_token=authenticate_user(@super_admin)

    post @register_path, params: admin_param(@area.id, @branch.id, user_type="manager", first_name="", email="some-email"), headers: { "Authorization" => "Bearer #{access_token}" }

    assert_response :bad_request
    response_data = JSON.parse(@response.body)

    assert_equal "The following required fields are missing: first_name. Please provide them to proceed.", response_data["error"]
  end

  test "should return error when user type is missing" do
    access_token=authenticate_user(@director)
    post @register_path, params: admin_param(@area.id, @branch.id, user_type="", first_name="Paul", email="some-email"), headers: { "Authorization" => "Bearer #{access_token}" }

    assert_response :bad_request
    response_data = JSON.parse(@response.body)

    assert_equal "User type is required. Please specify if you're registering an 'employee', 'manager', or 'director'.", response_data["error"]
  end

  test "should return error when user type is invalid" do
    access_token=authenticate_user(@manager)

    post @register_path, params: admin_param(@area.id, @branch.id, user_type="invalid", first_name="Paul", email="some-email"), headers: { "Authorization" => "Bearer #{access_token}" }

    assert_response :bad_request
    response_data = JSON.parse(@response.body)

    assert_equal "The user type you provided is invalid. Please provide a valid user type: 'employee', 'manager', or 'director'.", response_data["error"]
  end

  test "should return error when area is missing for manager" do
    access_token=authenticate_user(@director)

    post @register_path, params: admin_param(area_id="",  @branch.id, user_type="manager", first_name="Paul", email="some-email"), headers: { "Authorization" => "Bearer #{access_token}" }

    assert_response :bad_request
    response_data = JSON.parse(@response.body)

    assert_equal "The following required fields are missing: area_id. Please provide them to proceed.", response_data["error"]
  end

  test "should return error when area is missing for employee" do
    access_token=authenticate_user(@manager)

    post @register_path, params: employee_param(area_id="", @branch.id, first_name="Paul", email="some-email"), headers: { "Authorization" => "Bearer #{access_token}" }

    assert_response :bad_request
    response_data = JSON.parse(@response.body)

    assert_equal "The following required fields are missing: area_id. Please provide them to proceed.", response_data["error"]
  end

  test "should return error when branch is missing for employee" do
    access_token=authenticate_user(@manager)

    post @register_path, params: employee_param(@area.id, branch_id="", first_name="Paul", email="some-email"), headers: { "Authorization" => "Bearer #{access_token}" }

    assert_response :bad_request
    response_data = JSON.parse(@response.body)

    assert_equal "The following required fields are missing: branch_id. Please provide them to proceed.", response_data["error"]
  end

  test "should return error when branch is missing for director" do
    access_token=authenticate_user(@super_admin)

    post @register_path, params: admin_param(@area.id, branch_id="", user_type="director", first_name="Paul", email="some-email"), headers: { "Authorization" => "Bearer #{access_token}" }

    assert_response :bad_request
    response_data = JSON.parse(@response.body)

    assert_equal "The following required fields are missing: branch_id. Please provide them to proceed.", response_data["error"]
  end

  test "should return error if invalid branch id is provided" do
    access_token=authenticate_user(@director)

    non_existent_id = SecureRandom.uuid

    post @register_path, params: admin_param(@area.id, branch_id=non_existent_id, user_type="manager", first_name="Paul", email="someemail@gmail.com"), headers: { "Authorization" => "Bearer #{access_token}" }

    assert_response :bad_request
    response_data = JSON.parse(@response.body)

    assert_equal "The branch does not exist. Please provide a valid branch id.", response_data["error"]
  end

  test "should return error if invalid area id is provided" do
    access_token=authenticate_user(@director)

    non_existent_id = SecureRandom.uuid

    post @register_path, params: admin_param(non_existent_id, branch_id = @branch.id, user_type="manager", first_name="Paul", email="someemail@gmail.com"), headers: { "Authorization" => "Bearer #{access_token}" }

    assert_response :bad_request
    response_data = JSON.parse(@response.body)

    assert_equal "The area does not exist. Please provide a valid area id.", response_data["error"]
  end


  test "should return error when email is invalid for manager" do
    access_token=authenticate_user(@director)

    post @register_path, params: admin_param(@area.id, @branch.id, user_type="manager", first_name="Paul", email="some-email"), headers: { "Authorization" => "Bearer #{access_token}" }

    assert_response :bad_request
    response_data = JSON.parse(@response.body)

    assert_equal "The email provided is invalid. Please provide a valid email address.", response_data["error"]
  end

  test "should return error when email is invalid for employee" do
    access_token=authenticate_user(@manager)

    post @register_path, params: employee_param(@area.id, @branch.id, first_name="Paul", email="some-email"), headers: { "Authorization" => "Bearer #{access_token}" }

    assert_response :bad_request
    response_data = JSON.parse(@response.body)

    assert_equal "The email provided is invalid. Please provide a valid email address.", response_data["error"]
  end

  test "should return error if area does not belong to the branch" do
    access_token=authenticate_user(@manager)

    post @register_path, params: employee_param(@area2.id, @branch.id, first_name="Paul", email="someemail@gmail.com"), headers: { "Authorization" => "Bearer #{access_token}" }

    assert_response :bad_request
    response_data = JSON.parse(@response.body)

    assert_equal "The area does not belong to the specified branch.", response_data["error"]
  end

  test "should create manager with valid parameters" do
    access_token=authenticate_user(@director)

    post @register_path, params: admin_param(@area.id, @branch.id, user_type="manager", first_name="Henry", email="manager_one@gmail.co"), headers: { "Authorization" => "Bearer #{access_token}" }

    assert_response :created
    response_data = JSON.parse(@response.body)

    assert_equal "Henry", response_data["user"]["first_name"]
    assert_equal true, response_data["user"]["is_manager"]
    assert_equal false, response_data["user"]["is_director"]
    assert_equal false, response_data["user"]["is_super_admin"]
    assert_equal "Admin", response_data["user"]["last_name"]
    assert_equal "123456789", response_data["user"]["telephone"]
    assert_equal @branch.id, response_data["user"]["branch"]["id"]
    assert_equal @area.id, response_data["user"]["area"]["id"]
  end

  test "should return bad request if manager email is already taken" do
    access_token=authenticate_user(@director)

    post @register_path, params: admin_param(@area.id, @branch.id, user_type="manager", first_name="Paul", email=@manager.email), headers: { "Authorization" => "Bearer #{access_token}" }

    assert_response :bad_request
    assert_includes @response.body, "An account already exists with the email provided. Please use a different email address."
  end

  test "should create director with valid parameters" do
    access_token=authenticate_user(@super_admin)

    post @register_path, params: admin_param("", @branch.id, user_type="director", first_name="Paul", email="director_one@email.co"), headers: { "Authorization" => "Bearer #{access_token}" }

    assert_response :created
    response_data = JSON.parse(@response.body)

    assert_equal "Paul", response_data["user"]["first_name"]
    assert_equal false, response_data["user"]["is_manager"]
    assert_equal true, response_data["user"]["is_director"]
    assert_equal false, response_data["user"]["is_super_admin"]
    assert_equal "Admin", response_data["user"]["last_name"]
    assert_equal "123456789", response_data["user"]["telephone"]
    assert_equal @branch.id, response_data["user"]["branch"]["id"]
  end

  test "should return bad request if director email is already taken" do
    access_token=authenticate_user(@super_admin)

    post @register_path, params: admin_param("", @branch.id, user_type="director", first_name="Paul", email = @director.email), headers: { "Authorization" => "Bearer #{access_token}" }

    assert_response :bad_request
    assert_includes @response.body, "An account already exists with the email provided. Please use a different email address."
  end

  test "should create employee with valid parameters" do
    access_token=authenticate_user(@manager)

    post @register_path, params: employee_param(@area.id, @branch.id, first_name="Paul", email="tester@yahoo.com"), headers: { "Authorization" => "Bearer #{access_token}" }

    assert_response :created

    response_data = JSON.parse(@response.body)

    assert_equal "Paul", response_data["user"]["first_name"]
    assert_equal "Doe", response_data["user"]["last_name"]
    assert_equal "123456789", response_data["user"]["telephone"]
    assert_equal @branch.id, response_data["user"]["branch"]["id"]
    assert_equal @area.id, response_data["user"]["area"]["id"]
    assert_equal "123456", response_data["user"]["contract_code"]
    assert_not_nil response_data["user"]["shift_code"]
    assert_not_nil response_data["user"]["qr_code_url"]
    assert_equal ENV["S3_USER_BUCKET_URL"] + response_data["user"]["shift_code"] + "CompanyName.png", response_data["user"]["qr_code_url"]
    assert_equal "654321", response_data["user"]["tax_code"]
    assert_equal "1990-01-01", response_data["user"]["date_of_birth"]
    assert_equal "2021-01-01", response_data["user"]["contract_start_date"]
    assert_equal "2022-01-01", response_data["user"]["contract_end_date"]
    assert_equal false, response_data["user"]["is_deleted"]
    assert_equal true, response_data["user"]["is_active"]
    assert_equal "User created successfully", response_data["message"]
  end

  test "should return bad request if employee email is already taken" do
    access_token=authenticate_user(@manager)

    post @register_path, params: employee_param(@area.id, @branch.id, first_name="Paul", email= @employee1.email), headers: { "Authorization" => "Bearer #{access_token}" }

    assert_response :bad_request

    assert_includes @response.body, "An account already exists with the email provided. Please use a different email address."
  end

  # Helper method to simulate Cognito errors and test the response
  def simulate_cognito_error(error_type, error_message, error_code)
    access_token=authenticate_user(@director)

    @mock_cognito_service.stubs(:register_user).raises(error_type.new(error_message, error_code))

    post @register_path, params: admin_param(@area.id, @branch.id, user_type="manager", first_name="Henry", email="test-email@gmail.io"), headers: { "Authorization" => "Bearer #{access_token}" }

    assert_response :bad_request
    response_data = JSON.parse(@response.body)
    assert_equal error_message, response_data["error"]
  end

  test "should handle various Cognito errors gracefully" do
    simulate_cognito_error(Aws::CognitoIdentityProvider::Errors::InvalidPasswordException, "Password does not meet the requirements", "InvalidPassword")
    simulate_cognito_error(Aws::CognitoIdentityProvider::Errors::UserAlreadyExistsException, "User already exists", "UserExists")
    simulate_cognito_error(Aws::CognitoIdentityProvider::Errors::InvalidParameterException, "Invalid parameters", "InvalidParams")
    simulate_cognito_error(Aws::CognitoIdentityProvider::Errors::TooManyRequestsException, "Too many requests", "TooManyRequests")
  end
end
