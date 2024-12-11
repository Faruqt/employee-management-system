require "test_helper"

class OrganizationsControllerTest < ActionDispatch::IntegrationTest
  def setup
    setup_test_data
    setup_cognito_mock

    # Create extra test data
    @org2 = Organization.create!(name: "Organization Two", address: "Address Two")
    @org3 = Organization.create!(name: "Organization Three", address: "Address Three")

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

  def authenticate_super_admin
    user = @super_admin
    setup_cognito_mock_for_authentication(user.email)

    session = setup_authenticated_session(user)

    access_token = session[:access_token]

    access_token
  end

    [
    { user_type: "super_admin" }
    ].each do |params|
        define_method "test_should_return_default_paginated_organizations_for_#{params[:user_type]}" do
        user_type = params[:user_type]
        user=get_user_by_user_type(user_type)

        setup_cognito_mock_for_authentication(user.email)
        # Test with default pagination
        session = setup_authenticated_session(user)

        # Get the access token from the session data
        access_token = session[:access_token]

        get organizations_url, as: :json, headers: { "Authorization" => "Bearer #{access_token}" }
        assert_response :success

        response_data = JSON.parse(@response.body)
        organizations = response_data["organizations"]
        meta = response_data["meta"]

        assert_equal 1, meta["current_page"]
        assert_equal "Organization Three", organizations.first["name"] # Ordered by created_at: desc
      end
    end

            [
    { user_type: "director" },
    { user_type: "manager" }
    ].each do |params|
      define_method "test_should_return_error_for_#{params[:user_type]}" do
        user_type = params[:user_type]

        user = get_user_by_user_type(user_type)
        # Test with an unauthorized user
        setup_cognito_mock_for_authentication(user.email)
        session = setup_authenticated_session(user)

        # Get the access token from the session data
        access_token = session[:access_token]

        get organizations_url, as: :json, headers: { "Authorization" => "Bearer #{access_token}" }

        assert_response :unauthorized
        response_data = JSON.parse(@response.body)

        assert_equal "You are not authorized to perform this action", response_data["message"]

        end
      end

        [
    { user_type: "super_admin" }
    ].each do |params|
        define_method "test_should_return_custom_paginated_organizations_for_#{params[:user_type]}" do

        user_type = params[:user_type]

        user = get_user_by_user_type(user_type)

        setup_cognito_mock_for_authentication(user.email)

        # Test with custom page and per_page parameters
        session = setup_authenticated_session(user)

        # Get the access token from the session data
        access_token = session[:access_token]

        get organizations_url, params: { page: 1, per_page: 2 }, as: :json, headers: { "Authorization" => "Bearer #{access_token}" }

        assert_response :success

        response_data = JSON.parse(@response.body)
        organizations = response_data["organizations"]
        meta = response_data["meta"]

        assert_equal 2, organizations.size
        assert_equal 1, meta["current_page"]
        assert_not_nil meta["next_page"]
      end
    end


        [
    { user_type: "super_admin" }
    ].each do |params|
        define_method "test_should_return_empty_organizations_list_for_#{params[:user_type]}" do

        user_type = params[:user_type]

        user = get_user_by_user_type(user_type)

        setup_cognito_mock_for_authentication(user.email)

        # Test with custom page and per_page parameters
        session = setup_authenticated_session(user)

        # Get the access token from the session data
        access_token = session[:access_token]

        get organizations_url, params: { page: 7, per_page: 2 }, as: :json, headers: { "Authorization" => "Bearer #{access_token}" }

        assert_response :success


        response_data = JSON.parse(@response.body)
        organizations = response_data["organizations"]
        meta = response_data["meta"]

        assert_empty organizations
      end
    end

            [
    { user_type: "super_admin" }
    ].each do |params|
        define_method "test_should_return_correct_pagination_urls_for_#{params[:user_type]}" do

        user_type = params[:user_type]

        user = get_user_by_user_type(user_type)

        setup_cognito_mock_for_authentication(user.email)

        # Test with custom page and per_page parameters
        session = setup_authenticated_session(user)

        # Get the access token from the session data
        access_token = session[:access_token]

        get organizations_url, params: { page: 1, per_page: 2 }, as: :json, headers: { "Authorization" => "Bearer #{access_token}" }
        assert_response :success

        response_data = JSON.parse(@response.body)

        meta = response_data["meta"]

        assert_not_nil meta["next_page"]
        assert_nil meta["prev_page"]

        # Check next page
        get organizations_url, params: { page: 2, per_page: 2 }, as: :json, headers: { "Authorization" => "Bearer #{access_token}" }
        response_data = JSON.parse(@response.body)
        meta = response_data["meta"]

        assert_nil meta["next_page"]
        assert_not_nil meta["prev_page"]
      end
    end

                [
    { user_type: "director" },
    { user_type: "manager" }
    ].each do |params|
        define_method "test_should_return_unauthorized_for_#{params[:user_type]}" do

        user_type = params[:user_type]

        user = get_user_by_user_type(user_type)

        setup_cognito_mock_for_authentication(user.email)

        # Test with custom page and per_page parameters
        session = setup_authenticated_session(user)

        # Get the access token from the session data
        access_token = session[:access_token]

        # should not return organization details when valid ID is provided
        get organization_url(@org.id), as: :json, headers: { "Authorization" => "Bearer #{access_token}" }

        assert_response :unauthorized
        response_data = JSON.parse(@response.body)

        assert_equal "You are not authorized to perform this action", response_data["message"]

      end
  end

  test "should return organization details for super admin" do
    access_token = authenticate_super_admin

    get organization_url(@org.id), as: :json,  headers: { "Authorization" => "Bearer #{access_token}" }

    assert_response :success
    response_data = JSON.parse(@response.body)

    assert_equal @org.id, response_data["organization"]["id"]
    assert_equal @org.name, response_data["organization"]["name"]
    assert_equal @org.address, response_data["organization"]["address"]
  end

  test "should return 404 not found if organization does not exist" do
    access_token = authenticate_super_admin

    non_existent_id = SecureRandom.uuid
    get organization_url(non_existent_id), as: :json,  headers: { "Authorization" => "Bearer #{access_token}" }

    assert_response :not_found
    response_data = JSON.parse(response.body)
    assert_equal "Organization not found", response_data["error"]
  end

  test "should return 500 internal server error on unexpected error" do
    access_token = authenticate_super_admin

    # Simulate an unexpected error by stubbing the `find_by` method to raise an error
    Organization.stubs(:find_by).raises("Unexpected Error")

    get organization_url(@org.id), as: :json,  headers: { "Authorization" => "Bearer #{access_token}" }
    assert_response :internal_server_error
    response_data = JSON.parse(response.body)
    assert_equal "An error occurred while fetching organization, please try again", response_data["error"]
  end

  test "should create organization with valid parameters" do
    access_token = authenticate_super_admin

    # Simulate a successful organization creation
    post organizations_url, params: { name: "Latest Organization", address: "Address London" }, as: :json,  headers: { "Authorization" => "Bearer #{access_token}" }
    assert_response :created

    response_data = JSON.parse(@response.body)
    organization = response_data["organization"]

    assert_equal "Latest Organization", organization["name"]
    assert_equal "Address London", organization["address"]
  end

  test "should return error if name is missing" do
    access_token = authenticate_super_admin

    # Test when the 'name' parameter is missing
    post organizations_url, params: { address: "Address London" }, as: :json,  headers: { "Authorization" => "Bearer #{access_token}" }
    assert_response :bad_request

    response_data = JSON.parse(@response.body)
    assert_equal "Name is required", response_data["error"]
  end

   test "should return error if organization already exists" do
    # Test when trying to create an organization with an existing name
    access_token = authenticate_super_admin

    post organizations_url, params: { name: @org.name, address: "New Address" }, as: :json,  headers: { "Authorization" => "Bearer #{access_token}" }
    assert_response :bad_request

    response_data = JSON.parse(@response.body)
    assert_equal "Organization already exists with the name", response_data["error"]
  end

  test "should update organization with valid parameters" do
    access_token = authenticate_super_admin
    # Simulate a successful update
    patch organization_url(@org.id), params: { name: "Updated Organization", address: "Updated Address" }, as: :json,  headers: { "Authorization" => "Bearer #{access_token}" }
    assert_response :success

    response_data = JSON.parse(@response.body)
    organization = response_data["organization"]

    assert_equal "Updated Organization", organization["name"]
    assert_equal "Updated Address", organization["address"]
  end

  test "should return error if ID or name is missing" do
    # Test when the 'id' or 'name' parameter is missing
    access_token = authenticate_super_admin
    patch organization_url(@org.id), params: { address: "Updated Address" }, as: :json,  headers: { "Authorization" => "Bearer #{access_token}" }
    assert_response :bad_request

    response_data = JSON.parse(@response.body)
    assert_equal "Organization ID and name are required", response_data["error"]
  end

  test "should return error if organization does not exist" do
    access_token = authenticate_super_admin
    non_existent_id = SecureRandom.uuid
    patch organization_url(non_existent_id), params: { name: "New Name", address: "New Address" }, as: :json,  headers: { "Authorization" => "Bearer #{access_token}" }
    assert_response :not_found

    response_data = JSON.parse(@response.body)
    assert_equal "Organization not found", response_data["error"]
  end

  test "should return error if organization with the same name already exists" do
    # Test when trying to update the organization with an existing name
    access_token = authenticate_super_admin
    patch organization_url(@org.id), params: { name: @org2.name, address: "Updated Address" }, as: :json,  headers: { "Authorization" => "Bearer #{access_token}" }
    assert_response :bad_request

    response_data = JSON.parse(@response.body)
    assert_equal "An organization with this name already exists", response_data["error"]
  end

  test "should return error if update fails due to internal server error" do
    # Simulate an unexpected error by stubbing the `update` method on any instance of Organization
    access_token = authenticate_super_admin
    Organization.any_instance.stubs(:update!).raises(StandardError.new("Unexpected Error"))
    patch organization_url(@org.id), params: { name: "Some other updated name", address: "Updated Address" }, as: :json,  headers: { "Authorization" => "Bearer #{access_token}" }

    assert_response :internal_server_error

    response_data = JSON.parse(@response.body)
    assert_equal "Failed to update organization, please try again", response_data["error"]
  end

  test "should delete organization successfully" do
    access_token = authenticate_super_admin
    assert_difference("Organization.count", -1) do
      delete organization_url(@org3.id), as: :json,  headers: { "Authorization" => "Bearer #{access_token}" }
    end

    assert_response :ok
    response_data = JSON.parse(@response.body)
    assert_equal "Organization #{@org3.name} deleted successfully", response_data["message"]
  end

  test "should return error if organization is not found" do
    access_token = authenticate_super_admin
    non_existent_id = SecureRandom.uuid
    delete organization_url(non_existent_id), as: :json,  headers: { "Authorization" => "Bearer #{access_token}" }

    assert_response :not_found
    response_data = JSON.parse(@response.body)
    assert_equal "Organization not found", response_data["error"]
  end

  test "should return error if deleting an organization with branches" do
    # Test when trying to delete an organization with branches
    access_token = authenticate_super_admin
    delete organization_url(@org.id), as: :json,  headers: { "Authorization" => "Bearer #{access_token}" }

    assert_response :bad_request
    response_data = JSON.parse(@response.body)
    assert_equal "Organization has branches, delete branches and then try again", response_data["error"]
  end

  test "should return error if delete fails due to internal server error" do
    # Simulate error by stubbing the destroy method to raise an exception
    access_token = authenticate_super_admin
    Organization.any_instance.stubs(:destroy).raises(ActiveRecord::RecordNotDestroyed.new("Failed to delete"))

    delete organization_url(@org2.id), as: :json,  headers: { "Authorization" => "Bearer #{access_token}" }

    assert_response :internal_server_error
    response_data = JSON.parse(@response.body)
    assert_equal "Failed to delete organization, please try again", response_data["error"]
  end
end
