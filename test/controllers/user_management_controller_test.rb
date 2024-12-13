require "test_helper"

class UserManagementControllerTest < ActionDispatch::IntegrationTest
  def setup
    @archive_path = "/user/toggle_archive_state"
    @delete_path = "/user/"

    setup_test_data
    setup_cognito_mock

    # add extra user
    @employee2 = Employee.create!(first_name: "Gilbert", last_name: "Doe", email: "test_gilbert@gmail.co", telephone: "123456789", branch: @branch, area: @area, contract_code: "123456", tax_code: "654321", date_of_birth: "1990-01-01", contract_start_date: "2021-01-01", contract_end_date: "2022-01-01")
    @employee3 = Employee.create!(first_name: "Mary", last_name: "Doe", email: "test_mary@gmail.co", telephone: "123456789", branch: @branch, area: @area, contract_code: "123456", tax_code: "654321", date_of_birth: "1990-01-01", contract_start_date: "2021-01-01", contract_end_date: "2022-01-01")
    @employee4 = Employee.create!(first_name: "Joanna", last_name: "Doe", email: "test_joanna@gmail.co", telephone: "123456789", branch: @branch, area: @area, contract_code: "123456", tax_code: "654321", date_of_birth: "1990-01-01", contract_start_date: "2021-01-01", contract_end_date: "2022-01-01")
    @manager2 = Admin.create!(first_name: "Mark", last_name: "Doe", email: "test_mark_one@gmail.co", telephone: "123456789", admin_type: Admin.admin_types[:manager], branch: @branch, area: @area)
    @manager3 = Admin.create!(first_name: "Olivia", last_name: "Doe", email: "test_olivia_one@gmail.co", telephone: "123456789", admin_type: Admin.admin_types[:manager], branch: @branch, area: @area)
    @director2 = Admin.create!(first_name: "Jane", last_name: "Doe", email: "test_director_jane@gmail.co", telephone: "123456789", admin_type: Admin.admin_types[:director], branch: @branch)

  end

  def get_user_by_user_type(user_type)
    case user_type
    when "employee"
      @employee1
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

  [
    {user_type: "employee"},
    { user_type: "manager"},
    { user_type: "director"},
  ].each do |params|
    define_method("test_should_return_error_if_user_is_not_authenticated_#{params[:user_type]}") do
      user_type = params[:user_type]
      user = get_user_by_user_type(user_type)
      post @archive_path
      assert_response :unauthorized
      response_data = JSON.parse(response.body)
      assert_equal "Missing Authorization Header", response_data["message"]
    end
  end

  test "employee_should_not_be_able_to_archive_another_user" do
    user = @employee1
    access_token = authenticate_user(user)
    post @archive_path, headers: { "Authorization" => "Bearer #{access_token}" }

    assert_response :unauthorized

    response_data = JSON.parse(response.body)
    assert_equal "You are not authorized to perform this action", response_data["message"]
  end

    [
    {user_type: "super_admin"},
    { user_type: "manager"},
    { user_type: "director"},
  ].each do |params|
    define_method("test_admin_should_return_error_if_no_user_id_is_provided_#{params[:user_type]}") do
      user_type = params[:user_type]
      user = get_user_by_user_type(user_type)
      access_token = authenticate_user(user)
      post @archive_path, headers: {
        "Authorization" => "Bearer #{access_token}"}, params: { id: "" }

      assert_response :bad_request

      response_data = JSON.parse(response.body)

      assert_equal "User ID is required", response_data["error"]
    end
  end


  [
    {user_type: "super_admin"},
    { user_type: "manager"},
    { user_type: "director"},
  ].each do |params|
    define_method("test_admin_should_return_error_if_no_action_type_is_provided_#{params[:user_type]}") do
      user_type = params[:user_type]
      user = get_user_by_user_type(user_type)
      access_token = authenticate_user(user)

      post @archive_path, headers: {
        "Authorization" => "Bearer #{access_token}"}, params: { id: @employee2.id }
      
      assert_response :bad_request

      response_data = JSON.parse(response.body)

      assert_equal "Action type is required", response_data["error"]

    end
  end


  [
    {user_type: "super_admin"},
    { user_type: "manager"},
    { user_type: "director"},
  ].each do |params|
    define_method("test_admin_should_be_able_to_archive_another_user_#{params[:user_type]}") do
      user_type = params[:user_type]
      user = get_user_by_user_type(user_type)
      access_token = authenticate_user(user)
      post @archive_path, headers: { "Authorization" => "Bearer #{access_token}" }, params: { id: @employee2.id, "action_type" => "archive" }
      assert_response :ok

      response_data = JSON.parse(response.body)

      assert_equal "User archived successfully", response_data["message"]

      @employee2.reload
      assert_equal false, @employee2.is_active
      assert_equal false, response_data["user"]["is_active"]
    end
  end

  [
    {user_type: "super_admin"},
    { user_type: "manager"},
    { user_type: "director"},
  ].each do |params|
    define_method("test_admin_should_be_able_to_unarchive_another_user_#{params[:user_type]}") do
      user_type = params[:user_type]
      user = get_user_by_user_type(user_type)
      access_token = authenticate_user(user)
      post @archive_path, headers: { "Authorization" => "Bearer #{access_token}" }, params: { id: @employee2.id, "action_type" => "unarchive" }
      assert_response :ok

      response_data = JSON.parse(response.body)

      assert_equal "User unarchived successfully", response_data["message"]

      @employee2.reload
      assert_equal true, @employee2.is_active
      assert_equal true, response_data["user"]["is_active"]
    end
  end

  test "delete_user_should_return_error_if_user_id_is_not_valid" do
    non_existent_id = SecureRandom.uuid
    user = @super_admin
    access_token = authenticate_user(user)
    delete "#{@delete_path}#{non_existent_id}", headers: { "Authorization" => "Bearer #{access_token}" }

    assert_response :not_found

    response_data = JSON.parse(response.body)

    assert_equal "User not found", response_data["error"]
  end

  test "employee_should_not_be_able_to_delete_another_user" do
    user = @employee1
    access_token = authenticate_user(user)
    delete "#{@delete_path}#{@employee2.id}", headers: { "Authorization" => "Bearer #{access_token}" }

    assert_response :unauthorized

    response_data = JSON.parse(response.body)

    assert_equal "You are not authorized to perform this action", response_data["message"]
  end

  [
    {user_type: "employee"},
    { user_type: "manager"},
    { user_type: "director"},
  ].each do |params|
    define_method("test_delete_user_should_return_error_if_user_is_not_authenticated_#{params[:user_type]}") do
      user_type = params[:user_type]
      user = get_user_by_user_type(user_type)
      delete "#{@delete_path}#{@employee2.id}"

      assert_response :unauthorized
      response_data = JSON.parse(response.body)
      assert_equal "Missing Authorization Header", response_data["message"]
    end
  end

  test "manager should not be able to delete another manager" do
    user = @manager
    access_token = authenticate_user(user)
    delete "#{@delete_path}#{@manager2.id}", headers: { "Authorization" => "Bearer #{access_token}" }

    assert_response :unauthorized

    response_data = JSON.parse(response.body)

    assert_equal "You are not authorized to carry out this action", response_data["error"]

  end

  test "manager should not be able to delete a director" do
    user = @manager
    access_token = authenticate_user(user)

    delete "#{@delete_path}#{@director2.id}", headers: { "Authorization" => "Bearer #{access_token}" }

    assert_response :unauthorized

    response_data = JSON.parse(response.body)

    assert_equal "You are not authorized to carry out this action", response_data["error"]

  end

  test "director should not be able to delete another director" do
    user = @director
    access_token = authenticate_user(user)
    delete "#{@delete_path}#{@director2.id}", headers: { "Authorization" => "Bearer #{access_token}" }

    assert_response :unauthorized

    response_data = JSON.parse(response.body)

    assert_equal "You are not authorized to carry out this action", response_data["error"]

  end

  test "director should not be able to delete a super admin" do
    user = @director
    access_token = authenticate_user(user)
    delete "#{@delete_path}#{@super_admin.id}", headers: { "Authorization" => "Bearer #{access_token}" }

    assert_response :unauthorized

    response_data = JSON.parse(response.body)

    assert_equal "You are not authorized to carry out this action", response_data["error"]

  end

  test "super admin should be able to delete an employee" do
    user = @super_admin
    access_token = authenticate_user(user)
    delete "#{@delete_path}#{@employee2.id}", headers: { "Authorization" => "Bearer #{access_token}" }

    assert_response :ok

    response_data = JSON.parse(response.body)

    assert_equal "User deleted successfully", response_data["message"]

    @employee2.reload 

    # enure the user sensitive data is deleted
    assert_equal "Deleted", @employee2.first_name
    assert_equal "User", @employee2.last_name
    assert_equal "000000", @employee2.telephone
    assert_equal "deleted_user#{@employee2.id}@deleted.com" , @employee2.email
  end

  test "super admin should be able to delete a manager" do
    user = @super_admin
    access_token = authenticate_user(user)
    delete "#{@delete_path}#{@manager2.id}", headers: { "Authorization" => "Bearer #{access_token}" }

    assert_response :ok

    response_data = JSON.parse(response.body)

    assert_equal "User deleted successfully", response_data["message"]

    @manager2.reload

    # enure the user sensitive data is deleted

    assert_equal "Deleted", @manager2.first_name
    assert_equal "User", @manager2.last_name

    assert_equal "000000", @manager2.telephone
    assert_equal "deleted_user#{@manager2.id}@deleted.com" , @manager2.email
  end 

  test "super admin should be able to delete a director" do
    user = @super_admin
    access_token = authenticate_user(user)
    delete "#{@delete_path}#{@director2.id}", headers: { "Authorization" => "Bearer #{access_token}" }

    assert_response :ok

    response_data = JSON.parse(response.body)

    assert_equal "User deleted successfully", response_data["message"]

    @director2.reload

    # enure the user sensitive data is deleted

    assert_equal "Deleted", @director2.first_name
    assert_equal "User", @director2.last_name

    assert_equal "000000", @director2.telephone
    assert_equal "deleted_user#{@director2.id}@deleted.com" , @director2.email

  end

  test "director should be able to delete a manager" do
    user = @director
    access_token = authenticate_user(user)
    delete "#{@delete_path}#{@manager3.id}", headers: { "Authorization" => "Bearer #{access_token}" }

    assert_response :ok

    response_data = JSON.parse(response.body)

    assert_equal "User deleted successfully", response_data["message"]

    @manager3.reload

    # enure the user sensitive data is deleted

    assert_equal "Deleted", @manager3.first_name
    assert_equal "User", @manager3.last_name

    assert_equal "000000", @manager3.telephone
    assert_equal "deleted_user#{@manager3.id}@deleted.com" , @manager3.email
  end

  test "director should be able to delete an employee" do
    user = @director
    access_token = authenticate_user(user)

    delete "#{@delete_path}#{@employee3.id}", headers: { "Authorization" => "Bearer #{access_token}" }

    assert_response :ok

    response_data = JSON.parse(response.body)

    assert_equal "User deleted successfully", response_data["message"]

    @employee3.reload

    # enure the user sensitive data is deleted

    assert_equal "Deleted", @employee3.first_name
    assert_equal "User", @employee3.last_name

    assert_equal "000000", @employee3.telephone
    assert_equal "deleted_user#{@employee3.id}@deleted.com" , @employee3.email

  end

  test "manager should be able to delete an employee" do
    user = @manager
    access_token = authenticate_user(user)
    delete "#{@delete_path}#{@employee4.id}", headers: { "Authorization" => "Bearer #{access_token}" }

    assert_response :ok

    response_data = JSON.parse(response.body)

    assert_equal "User deleted successfully", response_data["message"]

    @employee4.reload

    # enure the user sensitive data is deleted

    assert_equal "Deleted", @employee4.first_name
    assert_equal "User", @employee4.last_name

    assert_equal "000000", @employee4.telephone
    assert_equal "deleted_user#{@employee4.id}@deleted.com" , @employee4.email
  end

end
