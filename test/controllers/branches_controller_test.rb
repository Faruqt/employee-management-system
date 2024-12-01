require "test_helper"

class BranchesControllerTest < ActionDispatch::IntegrationTest
  def setup
    # Create test data
    @org1 = Organization.create!(name: "Organization One", address: "Address One")
    @org2 = Organization.create!(name: "Organization Two", address: "Address Two")
    @branch1 = Branch.create!(name: "Branch-Organization 1", address: "Address One", organization_id: @org1.id)
    @branch2 = Branch.create!(name: "Branch-Organization 2", address: "Address Two", organization_id: @org2.id)
  end

  test "should return paginated branches" do
    # Test with default pagination
    get branches_url, as: :json
    assert_response :success

    response_data = JSON.parse(@response.body)
    branches = response_data["branches"]
    meta = response_data["meta"]

    assert_equal 2, meta["total_count"]
    assert_equal 1, meta["current_page"]
    assert_not_nil meta["total_pages"]
    assert_equal "Branch-Organization 2", branches.first["name"] # Ordered by created_at: desc
  end

  test "should handle custom pagination parameters" do
    # Test with custom page and per_page parameters
    get branches_url, params: { page: 1, per_page: 1 }, as: :json
    assert_response :success

    response_data = JSON.parse(@response.body)
    branches = response_data["branches"]
    meta = response_data["meta"]

    assert_equal 1, branches.size
    assert_equal 1, meta["current_page"]
    assert_equal 2, meta["total_pages"]
    assert_not_nil meta["next_page"]
  end

  test "should return empty branches list for out-of-range page" do
    get branches_url, params: { page: 5, per_page: 1 }, as: :json
    assert_response :success

    response_data = JSON.parse(@response.body)
    branches = response_data["branches"]
    meta = response_data["meta"]

    assert_empty branches
    assert_equal 5, meta["current_page"]
    assert_equal 2, meta["total_pages"]
  end

  test "should return correct next and previous page URLs" do
    # Test the next and prev URLs
    get branches_url, params: { page: 1, per_page: 1 }, as: :json
    assert_response :success

    response_data = JSON.parse(@response.body)
    meta = response_data["meta"]

    assert_not_nil meta["next_page"]
    assert_nil meta["prev_page"]
  end

  test "should return branch details when valid ID is provided" do
    get branch_url(@branch1), as: :json
    assert_response :success

    response_data = JSON.parse(@response.body)
    branch = response_data["branch"]

    assert_equal "Branch-Organization 1", branch["name"]
    assert_equal "Address One", branch["address"]
  end

  test "should return error for invalid branch ID" do
    non_existent_id = SecureRandom.uuid
    get branch_url(non_existent_id), as: :json

    assert_response :not_found
    response_data = JSON.parse(@response.body)
    assert_equal "Branch not found", response_data["error"]
  end

  test "should return 500 internal server error on unexpected error" do

    # Simulate an unexpected error by stubbing the `find_by` method to raise an error
    Branch.stubs(:find_by).raises("Unexpected Error")

    get branch_url(@branch1.id), as: :json
    assert_response :internal_server_error
    response_data = JSON.parse(response.body)
    assert_equal "An error occurred while fetching branch, please try again", response_data["error"]
  end

  test "should create a new branch" do
    # Simulate a successful branch creation
    post branches_url, params: { name: "Branch-Organization 3", address: "Address Three", organization_id: @org1.id }, as: :json
    assert_response :created

    assert JSON.parse(@response.body)["branch"]
    assert JSON.parse(@response.body)["branch"]["id"]
    assert_equal "Branch-Organization 3", JSON.parse(@response.body)["branch"]["name"]
    assert_equal "Address Three", JSON.parse(@response.body)["branch"]["address"]
    assert JSON.parse(@response.body)["branch"]["organization_id"]
    assert_equal @org1.id, JSON.parse(@response.body)["branch"]["organization_id"]
    assert_equal "Branch created successfully", JSON.parse(@response.body)["message"]

  end

  test "should return error for missing branch name" do
    # Test with missing branch name
    post branches_url, params: { address: "Address Three", organization_id: @org1.id }, as: :json
    assert_response :bad_request

    response_data = JSON.parse(@response.body)
    assert_equal "Branch name is required", JSON.parse(@response.body)["error"]
  end

  test "should return if branch already exists in the organiztion" do
    # Test with existing branch name
    post branches_url, params: { name: "Branch-Organization 1", address: "Address Three", organization_id: @org1.id }, as: :json
    assert_response :bad_request

    response_data = JSON.parse(@response.body)
    assert_equal "Branch already exists with the name", JSON.parse(@response.body)["error"]
  end

  test "should update branch with valid parameters" do
    # Simulate a successful branch update
    patch branch_url(@branch1), params: { name: "Branch-Organization 1 Updated", address: "Address One Updated" }, as: :json
    assert_response :success

    assert JSON.parse(@response.body)["branch"]
    assert_equal "Branch-Organization 1 Updated", JSON.parse(@response.body)["branch"]["name"]
    assert_equal "Address One Updated", JSON.parse(@response.body)["branch"]["address"]
    assert_equal "Branch updated successfully", JSON.parse(@response.body)["message"]
  end

  test "should return error if branch name is not provided during update" do
    # Test with missing branch name
    patch branch_url(@branch1), params: { address: "Address One Updated" }, as: :json
    assert_response :bad_request

    response_data = JSON.parse(@response.body)
    assert_equal "Branch name is required", JSON.parse(@response.body)["error"]
  end

  test "should return error if branch does not exist during update" do 
    non_existent_id = SecureRandom.uuid
    patch branch_url(non_existent_id), params: { name: "Branch-Organization 1 Updated", address: "Address One Updated" }, as: :json
    assert_response :not_found

    response_data = JSON.parse(@response.body)
    assert_equal "Branch not found", response_data["error"]
  end

  test "should return error if branch with the same name already exists" do
    # Test with existing branch name
    patch branch_url(@branch1), params: { name: "Branch-Organization 2", address: "Address One Updated" }, as: :json
    assert_response :bad_request

    response_data = JSON.parse(@response.body)
    assert_equal "Branch already exists with the name", response_data["error"]
  end

  test "should return error if update fails due to internal server error" do
    # Simulate an internal server error by stubbing the `update` method to raise an error
    Branch.any_instance.stubs(:update!).raises(StandardError.new("Unexpected Error"))
    patch branch_url(@branch1), params: { name: "Branch-Organization 1 Updated", address: "Address One Updated" }, as: :json
    assert_response :internal_server_error

    response_data = JSON.parse(@response.body)
    assert_equal "An error occurred while updating branch, please try again", response_data["error"]
  end

  test "should delete branch successfully" do
    assert_difference('Branch.count', -1) do
      delete branch_url(@branch1), as: :json
    end

    assert_response :success
    assert_equal "Branch #{@branch1.name} deleted successfully", JSON.parse(@response.body)["message"]
  end

  test "should return error if branch does not exist during delete" do
    non_existent_id = SecureRandom.uuid
    delete branch_url(non_existent_id), as: :json
    assert_response :not_found

    response_data = JSON.parse(@response.body)
    assert_equal "Branch not found", response_data["error"]
  end

  test "should return error if delete fails due to internal server error" do
    # Simulate an internal server error by stubbing the `destroy` method to raise an error
    Branch.any_instance.stubs(:destroy).raises("Unexpected Error")

    delete branch_url(@branch1), as: :json
    assert_response :internal_server_error

    response_data = JSON.parse(@response.body)
    assert_equal "An error occurred while deleting branch, please try again", response_data["error"]
  end
end
