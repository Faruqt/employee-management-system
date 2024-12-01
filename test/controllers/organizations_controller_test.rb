require "test_helper"

class OrganizationsControllerTest < ActionDispatch::IntegrationTest
  def setup
    # Create test data
    @org1 = Organization.create!(name: "Organization One", address: "Address One")
    @org2 = Organization.create!(name: "Organization Two", address: "Address Two")
    @org3 = Organization.create!(name: "Organization Three", address: "Address Three")
  end

  test "should return paginated organizations" do
    # Test with default pagination
    get organizations_url, as: :json
    assert_response :success

    response_data = JSON.parse(@response.body)
    organizations = response_data["organizations"]
    meta = response_data["meta"]

    assert_equal 3, meta["total_count"]
    assert_equal 1, meta["current_page"]
    assert_not_nil meta["total_pages"]
    assert_equal "Organization Three", organizations.first["name"] # Ordered by created_at: desc
  end

  test "should handle custom pagination parameters" do
    # Test with custom page and per_page parameters
    get organizations_url, params: { page: 1, per_page: 2 }, as: :json
    assert_response :success

    response_data = JSON.parse(@response.body)
    organizations = response_data["organizations"]
    meta = response_data["meta"]

    assert_equal 2, organizations.size
    assert_equal 1, meta["current_page"]
    assert_equal 2, meta["total_pages"]
    assert_not_nil meta["next_page"]
  end

  test "should return empty organizations list for out-of-range page" do
    get organizations_url, params: { page: 5, per_page: 2 }, as: :json
    assert_response :success

    response_data = JSON.parse(@response.body)
    organizations = response_data["organizations"]
    meta = response_data["meta"]

    assert_empty organizations
    assert_equal 5, meta["current_page"]
    assert_equal 2, meta["total_pages"]
  end

  test "should return correct next and previous page URLs" do
    # Test the next and prev URLs
    get organizations_url, params: { page: 1, per_page: 2 }, as: :json
    assert_response :success

    response_data = JSON.parse(@response.body)

    meta = response_data["meta"]

    assert_not_nil meta["next_page"]
    assert_nil meta["prev_page"]

    # Check next page
    get organizations_url, params: { page: 2, per_page: 2 }, as: :json
    response_data = JSON.parse(@response.body)
    meta = response_data["meta"]

    assert_nil meta["next_page"]
    assert_not_nil meta["prev_page"]
  end

  test "should return organization details when valid ID is provided" do
    get organization_url(@org1.id)

    assert_response :success
    response_body = JSON.parse(response.body)
    assert_equal @org1.id, response_body["organization"]["id"]
    assert_equal @org1.name, response_body["organization"]["name"]
    assert_equal @org1.address, response_body["organization"]["address"]
  end

  test "should return 404 not found if organization does not exist" do
    non_existent_id = SecureRandom.uuid
    get organization_url(non_existent_id)

    assert_response :not_found
    response_body = JSON.parse(response.body)
    assert_equal "Organization not found", response_body["error"]
  end

  test "should return 500 internal server error on unexpected error" do
    # Simulate an unexpected error by stubbing the `find_by` method to raise an error
    Organization.stubs(:find_by).raises("Unexpected Error")

    get organization_url(@org1.id), as: :json
    assert_response :internal_server_error
    response_body = JSON.parse(response.body)
    assert_equal "An error occurred while fetching organization, please try again", response_body["error"]
  end

  test "should create organization with valid parameters" do
    # Simulate a successful organization creation
    post organizations_url, params: { name: "Latest Organization", address: "Address London" }, as: :json
    assert_response :created

    response_data = JSON.parse(@response.body)
    organization = response_data["organization"]

    assert_equal "Latest Organization", organization["name"]
    assert_equal "Address London", organization["address"]
  end

  test "should return error if name is missing" do
    # Test when the 'name' parameter is missing
    post organizations_url, params: { address: "Address London" }, as: :json
    assert_response :bad_request

    response_data = JSON.parse(@response.body)
    assert_equal "Name is required", response_data["error"]
  end

   test "should return error if organization already exists" do
    # Test when trying to create an organization with an existing name
    post organizations_url, params: { name: @org1.name, address: "New Address" }, as: :json
    assert_response :bad_request

    response_data = JSON.parse(@response.body)
    assert_equal "Organization already exists with the name", response_data["error"]
  end

  test "should update organization with valid parameters" do
    # Simulate a successful update
    patch organization_url(@org1.id), params: { name: "Updated Organization", address: "Updated Address" }, as: :json
    assert_response :success

    response_data = JSON.parse(@response.body)
    organization = response_data["organization"]

    assert_equal "Updated Organization", organization["name"]
    assert_equal "Updated Address", organization["address"]
  end

  test "should return error if ID or name is missing" do
    # Test when the 'id' or 'name' parameter is missing
    patch organization_url(@org1.id), params: { address: "Updated Address" }, as: :json
    assert_response :bad_request

    response_data = JSON.parse(@response.body)
    assert_equal "Organization ID and name are required", response_data["error"]
  end

  test "should return error if organization does not exist" do
    non_existent_id = SecureRandom.uuid
    patch organization_url(non_existent_id), params: { name: "New Name", address: "New Address" }, as: :json
    assert_response :not_found

    response_data = JSON.parse(@response.body)
    assert_equal "Organization not found", response_data["error"]
  end

  test "should return error if organization with the same name already exists" do
    # Test when trying to update the organization with an existing name
    patch organization_url(@org1.id), params: { name: @org2.name, address: "Updated Address" }, as: :json
    assert_response :bad_request

    response_data = JSON.parse(@response.body)
    assert_equal "An organization with this name already exists", response_data["error"]
  end

  test "should return error if update fails due to internal server error" do
    # Simulate an unexpected error by stubbing the `update` method on any instance of Organization
    Organization.any_instance.stubs(:update!).raises(StandardError.new("Unexpected Error"))
    patch organization_url(@org1.id), params: { name: "Some other updated name", address: "Updated Address" }, as: :json

    assert_response :internal_server_error

    response_data = JSON.parse(@response.body)
    assert_equal "Failed to update organization, please try again", response_data["error"]
  end

  test "should delete organization successfully" do
    assert_difference("Organization.count", -1) do
      delete organization_url(@org1.id), as: :json
    end

    assert_response :ok
    response_data = JSON.parse(@response.body)
    assert_equal "Organization #{@org1.name} deleted successfully", response_data["message"]
  end

  test "should return error if organization is not found" do
    non_existent_id = SecureRandom.uuid
    delete organization_url(non_existent_id), as: :json

    assert_response :not_found
    response_data = JSON.parse(@response.body)
    assert_equal "Organization not found", response_data["error"]
  end

  test "should return error if delete fails due to internal server error" do
    # Simulate error by stubbing the destroy method to raise an exception
    Organization.any_instance.stubs(:destroy).raises(ActiveRecord::RecordNotDestroyed.new("Failed to delete"))

    delete organization_url(@org1.id), as: :json

    assert_response :internal_server_error
    response_data = JSON.parse(@response.body)
    assert_equal "Failed to delete organization, please try again", response_data["error"]
  end
end
