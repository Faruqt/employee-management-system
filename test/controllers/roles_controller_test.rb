require "test_helper"

class RolesControllerTest < ActionDispatch::IntegrationTest
  def setup
    # Create test data
    @area1 = Area.create!(name: "Area One", color: "Color One")
    @area2 = Area.create!(name: "Area Two", color: "Color Two")
    @role1 = Role.create!(name: "Role One", symbol: "Role One Symbol", area_id: @area1.id)
    @role2 = Role.create!(name: "Role Two", symbol: "Role Two Symbol", area_id: @area2.id)
    @role3 = Role.create!(name: "Role Three", symbol: "Role Three Symbol", area_id: @area2.id)
  end

  test "should return paginated roles" do
    # Test with default pagination
    get roles_url, as: :json
    assert_response :success

    response_data = JSON.parse(@response.body)
    roles = response_data["roles"]
    meta = response_data["meta"]

    assert_equal 3, meta["total_count"]
    assert_equal 1, meta["current_page"]
    assert_not_nil meta["total_pages"]
    assert_equal "Role Three", roles.first["name"] # Ordered by created_at: desc
  end

  test "should handle custom pagination parameters" do
    # Test with custom page and per_page parameters
    get roles_url, params: { page: 1, per_page: 1 }, as: :json
    assert_response :success

    response_data = JSON.parse(@response.body)
    roles = response_data["roles"]
    meta = response_data["meta"]

    assert_equal 1, roles.size
    assert_equal 1, meta["current_page"]
    assert_equal 3, meta["total_pages"]
    assert_not_nil meta["next_page"]
  end

  test "should return empty roles list for out-of-range page" do
    get roles_url, params: { page: 5, per_page: 1 }, as: :json
    assert_response :success

    response_data = JSON.parse(@response.body)
    roles = response_data["roles"]
    meta = response_data["meta"]

    assert_empty roles
    assert_equal 5, meta["current_page"]
    assert_equal 3, meta["total_pages"]
  end

  test "should return correct next and previous page URLs" do
    # Test the next and prev URLs
    get roles_url, params: { page: 1, per_page: 1 }, as: :json
    assert_response :success

    response_data = JSON.parse(@response.body)
    meta = response_data["meta"]

    assert_not_nil meta["next_page"]
    assert_nil meta["prev_page"]
  end

  test "should return role by ID" do
    get role_url(@role1), as: :json
    assert_response :success
  
    response_data = JSON.parse(@response.body)
    role = response_data["role"]

    assert_equal "Role One", role["name"]
    assert_equal "Role One Symbol", role["symbol"]
    assert_equal @area1.id, role["area_id"]
  end

  test "should return error for invalid role ID" do
    non_existent_id = SecureRandom.uuid
    get role_url(non_existent_id), as: :json
    assert_response :not_found

    response_data = JSON.parse(@response.body)
    assert_equal "Role not found", response_data["error"]
  end

  test "should return 500 internal server error on unexpected error" do
    # Simulate an unexpected error by stubbing the `find_by` method to raise an error

    Role.stubs(:find_by).raises(StandardError)
    get role_url(@role1), as: :json
    assert_response :internal_server_error
    response_data = JSON.parse(@response.body)
    assert_equal "An error occurred while fetching role, please try again", response_data["error"]
  end

  test "should create a new role" do
    # Simulate a successful role creation
    post roles_url, params: { name: "Role Four", symbol: "Role Four Symbol", area_id: @area1.id }, as: :json
    assert_response :success

    assert JSON.parse(@response.body)["role"]
    assert JSON.parse(@response.body)["role"]["id"]
    assert_equal "Role Four", JSON.parse(@response.body)["role"]["name"]
    assert_equal "Role Four Symbol", JSON.parse(@response.body)["role"]["symbol"]
    assert_equal @area1.id, JSON.parse(@response.body)["role"]["area_id"]
    assert JSON.parse(@response.body)["role"]["created_at"]
    assert JSON.parse(@response.body)["role"]["updated_at"]
    assert_equal "Role created successfully", JSON.parse(@response.body)["message"]
  end 

  test "should return error for missing role name" do
    # Test with missing role name
    post roles_url, params: { symbol: "Role Four Symbol", area_id: @area1.id }, as: :json
    assert_response :bad_request

    response_data = JSON.parse(@response.body)
    assert_equal "Name is required", response_data["error"]
  end

  test "should return error for missing role symbol" do
    # Test with missing role symbol
    post roles_url, params: { name: "Role Four", area_id: @area1.id }, as: :json
    assert_response :bad_request

    response_data = JSON.parse(@response.body)
    assert_equal "Symbol is required", response_data["error"]
  end

  test "should return error if name already exists in that area" do 
    # Test with existing role name
    post roles_url, params: { name: "Role One", symbol: "Role Four Symbol", area_id: @area1.id }, as: :json
    assert_response :bad_request

    response_data = JSON.parse(@response.body)
    assert_equal "Role already exists with the name", response_data["error"]
  end

  test "should create role wth same name in a different area" do
    # Test with same role name in a different area
    post roles_url, params: { name: "Role One", symbol: "Role Four Symbol", area_id: @area2.id }, as: :json
    assert_response :success

    response_data = JSON.parse(@response.body)
    assert_equal "Role created successfully", response_data["message"]
    assert JSON.parse(@response.body)["role"]
    assert JSON.parse(@response.body)["role"]["id"]
    assert_equal "Role One", JSON.parse(@response.body)["role"]["name"]
    assert_equal "Role Four Symbol", JSON.parse(@response.body)["role"]["symbol"]
    assert_equal @area2.id, JSON.parse(@response.body)["role"]["area_id"]
    assert JSON.parse(@response.body)["role"]["created_at"]


  end

  test "should update role with valid parameters" do
    # Simulate a successful role update
    patch role_url(@role1), params: { name: "Role One Updated", symbol: "Role One Symbol Updated" }, as: :json
    assert_response :success

    assert JSON.parse(@response.body)["role"]
    assert_equal "Role One Updated", JSON.parse(@response.body)["role"]["name"]
    assert_equal "Role One Symbol Updated", JSON.parse(@response.body)["role"]["symbol"]
    assert_equal "Role updated successfully", JSON.parse(@response.body)["message"]
  end

  test "should return error if role name is not provided during update" do
    # Test with missing role name
    patch role_url(@role1), params: { symbol: "Role One Symbol Updated" }, as: :json
    assert_response :bad_request

    response_data = JSON.parse(@response.body)
    assert_equal "Name is required", response_data["error"]
  end

  test "should return error if role does not exist during update" do
    non_existent_id = SecureRandom.uuid
    patch role_url(non_existent_id), params: { name: "Role One Updated", symbol: "Role One Symbol Updated" }, as: :json
    assert_response :not_found

    response_data = JSON.parse(@response.body)
    assert_equal "Role not found", response_data["error"]
  end

  test "should return error if role with the same name already exists" do
    # Test with existing role name
    patch role_url(@role3), params: { name: "Role Two", symbol: "Role Three Symbol Updated" }, as: :json
    assert_response :bad_request

    response_data = JSON.parse(@response.body)
    assert_equal "Role already exists with the name", response_data["error"]
  end

  test "should update role with same name in a different area" do
    # Test with same role name in a different area
    patch role_url(@role1), params: { name: "Role Two", symbol: "Role One Symbol Updated", area_id: @area1.id }, as: :json
    assert_response :success

    response_data = JSON.parse(@response.body)
    assert_equal "Role updated successfully", response_data["message"]
    assert JSON.parse(@response.body)["role"]
    assert_equal "Role Two", JSON.parse(@response.body)["role"]["name"]
    assert_equal "Role One Symbol Updated", JSON.parse(@response.body)["role"]["symbol"]
    assert_equal @area1.id, JSON.parse(@response.body)["role"]["area_id"]
  end

  test "should return error if symbol not provided during update" do
    # Test with missing role symbol
    patch role_url(@role1), params: { name: "Role One Updated" }, as: :json
    assert_response :bad_request

    response_data = JSON.parse(@response.body)
    assert_equal "Symbol is required", response_data["error"]
  end

  test "should return error if update fails due to internal server error" do 
    # Simulate an unexpected error by stubbing the `update!` method to raise an error
    Role.any_instance.stubs(:update!).raises(StandardError)
    patch role_url(@role1), params: { name: "Role One Updated", symbol: "Role One Symbol Updated" }, as: :json
    assert_response :internal_server_error

    response_data = JSON.parse(@response.body)
    assert_equal "An error occurred while updating role, please try again", response_data["error"]
  end

  test "should delete role successfully" do
    assert_difference("Role.count", -1) do
      delete role_url(@role1), as: :json
    end

    assert_response :ok
    response_data = JSON.parse(@response.body)
    assert_equal "Role Role One deleted successfully", response_data["message"]
  end

  test "should return error if role does not exist during delete" do
    non_existent_id = SecureRandom.uuid
    delete role_url(non_existent_id), as: :json
    assert_response :not_found

    response_data = JSON.parse(@response.body)
    assert_equal "Role not found", response_data["error"]
  end

  test "should return 500 internal server error if delete role fails" do
    # Simulate an unexpected error by stubbing the `destroy` method to raise an error
    Role.any_instance.stubs(:destroy).raises(StandardError)
    delete role_url(@role1), as: :json
    assert_response :internal_server_error

    response_data = JSON.parse(@response.body)
    assert_equal "An error occurred while deleting role, please try again", response_data["error"]
  end   
end
