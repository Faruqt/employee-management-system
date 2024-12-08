require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  def setup
    # Create test data
    @org = Organization.create!(name: "Organization One", address: "Address One")
    @branch = Branch.create!(name: "Branch One", address: "Branch Address One", organization: @org)
    @area = Area.create!(name: "Area One", color: "Color One")
    @branch.areas << @area
    @manager1 = Admin.create!(first_name: "John", last_name: "Doe", email: "test_manager_one@gmail.co", telephone: "123456789", is_manager: true, branch: @branch, area: @area)
    @director1 = Admin.create!(first_name: "Jane", last_name: "Doe", email: "test_director_one@gmail.co", telephone: "123456789", is_director: true, branch: @branch)

    setup_cognito_mock
  end

  # def employee_param(email="john_doe@gmail.com")
  #   {
  #     first_name: "John",
  #     last_name: "Doe",
  #     email: email,
  #     telephone: "123456789",
  #     branch_id: @branch.id,
  #     area_id: @area.id,
  #     contract_code: "123456",
  #     tax_code: "654321",
  #     date_of_birth: "1990-01-01",
  #     contract_start_date: "2021-01-01",
  #     contract_end_date: "2022-01-01",
  #     user_type: "employee"
  #   }
  # end

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

  # test "should create employee" do
  #   post '/register', params: employee_param

  #   assert_response :created
  #   assert_equal 'John', assigns(:user).first_name
  # end

  test "should return bad request if missing required parameters" do
    post "/auth/register", params: admin_param(@area.id, @branch.id, user_type="manager", first_name="", email="some-email")

    assert_response :bad_request
    response_data = JSON.parse(@response.body)

    assert_equal "The following required fields are missing: first_name. Please provide them to proceed.", response_data["error"]
  end

  test "should return error when user type is missing" do
    post "/auth/register", params: admin_param(@area.id, @branch.id, user_type="", first_name="Paul", email="some-email")

    assert_response :bad_request
    response_data = JSON.parse(@response.body)

    assert_equal "User type is required. Please specify if you're registering an 'employee', 'manager', or 'director'.", response_data["error"]
  end

  test "should return error when user type is invalid" do
    post "/auth/register", params: admin_param(@area.id, @branch.id, user_type="invalid", first_name="Paul", email="some-email")

    assert_response :bad_request
    response_data = JSON.parse(@response.body)

    assert_equal "The user type you provided is invalid. Please provide a valid user type: 'employee', 'manager', or 'director'.", response_data["error"]
  end

  test "should return error when area is missing for manager" do
    post "/auth/register", params: admin_param(area_id="",  @branch.id, user_type="manager", first_name="Paul", email="some-email")

    assert_response :bad_request
    response_data = JSON.parse(@response.body)

    assert_equal "The following required fields are missing: area_id. Please provide them to proceed.", response_data["error"]
  end

  test "should return error when branch is missing for director" do
    post "/auth/register", params: admin_param(@area.id, branch_id="", user_type="director", first_name="Paul", email="some-email")

    assert_response :bad_request
    response_data = JSON.parse(@response.body)

    assert_equal "The following required fields are missing: branch_id. Please provide them to proceed.", response_data["error"]
  end

  test "should return error when email is invalid" do
    post "/auth/register", params: admin_param(@area.id, @branch.id, user_type="manager", first_name="Paul", email="some-email")

    assert_response :bad_request
    response_data = JSON.parse(@response.body)

    assert_equal "The email provided is invalid. Please provide a valid email address.", response_data["error"]
  end

  test "should create manager with valid parameters" do
    post "/auth/register", params: admin_param(@area.id, @branch.id, user_type="manager", first_name="Henry", email="manager_one@gmail.co")

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

  test "should return bad request if email is already taken" do
    post "/auth/register", params: admin_param(@area.id, @branch.id, user_type="manager", first_name="Paul", email=@manager1.email)

    assert_response :bad_request
    assert_includes @response.body, "Account already exists with the email"
  end

  test "should create director with valid parameters" do
    post "/auth/register", params: admin_param("", @branch.id, user_type="director", first_name="Paul", email="director_one@email.co")

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

   test "should handle Cognito ServiceError gracefully" do
    # Simulate a Cognito ServiceError
    @mock_cognito_service.stubs(:register_user).raises(Aws::CognitoIdentityProvider::Errors::ServiceError.new("An error occurred", "ServiceError"))

    post "/auth/register", params: admin_param(@area.id, @branch.id, user_type="manager", first_name="Henry", email="test-email@gmail.io")

    assert_response :internal_server_error
    response_data = JSON.parse(@response.body)

    assert_equal "An error occurred while creating user, please try again", response_data["error"]
   end
end
