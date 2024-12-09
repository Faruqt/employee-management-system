require "test_helper"

class BranchesControllerTest < ActionDispatch::IntegrationTest
  def setup

    setup_test_data
    setup_cognito_mock

    # Create extra test data
    @org2 = Organization.create!(name: "Organization Branch Two", address: "Address Two")
    @branch2 = Branch.create!(name: "Branch-Organization 2", address: "Address Two", organization_id: @org2.id)
  end

  def authenticate_user(user)
    setup_cognito_mock_for_authentication(user.email)

    session = setup_authenticated_session(user)

    access_token = session[:access_token]

    access_token
  end

  test "should return paginated branches" do
    # Test with default pagination

    access_token=authenticate_user(@director1)
    get branches_url, as: :json, headers: { "Authorization" => "Bearer #{access_token}" }
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
    access_token=authenticate_user(@director1)
    # Test with custom page and per_page parameters
    get branches_url, params: { page: 1, per_page: 1 }, as: :json, headers: { "Authorization" => "Bearer #{access_token}" }
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
    access_token=authenticate_user(@director1)
    get branches_url, params: { page: 5, per_page: 1 }, as: :json, headers: { "Authorization" => "Bearer #{access_token}" }
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
    access_token=authenticate_user(@super_admin)

    get branches_url, params: { page: 1, per_page: 1 }, as: :json, headers: { "Authorization" => "Bearer #{access_token}" }
    assert_response :success

    response_data = JSON.parse(@response.body)
    meta = response_data["meta"]

    assert_not_nil meta["next_page"]
    assert_nil meta["prev_page"]
  end

  test "should return branch details when valid ID is provided" do
    access_token=authenticate_user(@super_admin)

    get branch_url(@branch), as: :json, headers: { "Authorization" => "Bearer #{access_token}" }
    assert_response :success

    response_data = JSON.parse(@response.body)
    branch = response_data["branch"]

    assert_equal "Branch One", branch["name"]
    assert_equal "Branch Address One", branch["address"]
  end

  test "should return error for invalid branch ID" do
    access_token=authenticate_user(@director1)

    non_existent_id = SecureRandom.uuid
    get branch_url(non_existent_id), as: :json, headers: { "Authorization" => "Bearer #{access_token}" }

    assert_response :not_found
    response_data = JSON.parse(@response.body)
    assert_equal "Branch not found", response_data["error"]
  end

  test "should return 500 internal server error on unexpected error" do
    access_token=authenticate_user(@director1)

    # Simulate an unexpected error by stubbing the `find_by` method to raise an error
    Branch.stubs(:find_by).raises("Unexpected Error")

    get branch_url(@branch.id), as: :json, headers: { "Authorization" => "Bearer #{access_token}" }
    assert_response :internal_server_error
    response_data = JSON.parse(response.body)
    assert_equal "An error occurred while fetching branch, please try again", response_data["error"]
  end

  test "should create a new branch" do
    access_token=authenticate_user(@director1)

    # Simulate a successful branch creation
    post branches_url, params: { name: "Branch-Organization 3", address: "Address Three", organization_id: @org.id }, as: :json, headers: { "Authorization" => "Bearer #{access_token}" }
    assert_response :created

    assert JSON.parse(@response.body)["branch"]
    assert JSON.parse(@response.body)["branch"]["id"]
    assert_equal "Branch-Organization 3", JSON.parse(@response.body)["branch"]["name"]
    assert_equal "Address Three", JSON.parse(@response.body)["branch"]["address"]
    assert JSON.parse(@response.body)["branch"]["organization_id"]
    assert_equal @org.id, JSON.parse(@response.body)["branch"]["organization_id"]
    assert_equal "Branch created successfully", JSON.parse(@response.body)["message"]
  end

  test "should return error for missing branch name" do
    access_token=authenticate_user(@super_admin)

    # Test with missing branch name
    post branches_url, params: { address: "Address Three", organization_id: @org.id }, as: :json, headers: { "Authorization" => "Bearer #{access_token}" }
    assert_response :bad_request

    response_data = JSON.parse(@response.body)
    assert_equal "Branch name is required", JSON.parse(@response.body)["error"]
  end

  test "should return error if branch already exists in the organiztion" do
    access_token=authenticate_user(@director1)

    # Test with existing branch name
    post branches_url, params: { name: "Branch-Organization 2", address: "Address Three", organization_id: @org2.id }, as: :json, headers: { "Authorization" => "Bearer #{access_token}" }
    assert_response :bad_request

    response_data = JSON.parse(@response.body)
    assert_equal "Branch already exists with the name", JSON.parse(@response.body)["error"]
  end

  test "should update branch with valid parameters" do
    access_token=authenticate_user(@director1)

    # Simulate a successful branch update
    patch branch_url(@branch), params: { name: "Branch-Organization 1 Updated", address: "Address One Updated" }, as: :json, headers: { "Authorization" => "Bearer #{access_token}" }
    assert_response :success

    assert JSON.parse(@response.body)["branch"]
    assert_equal "Branch-Organization 1 Updated", JSON.parse(@response.body)["branch"]["name"]
    assert_equal "Address One Updated", JSON.parse(@response.body)["branch"]["address"]
    assert_equal "Branch updated successfully", JSON.parse(@response.body)["message"]
  end

  test "should return error if branch name is not provided during update" do
    access_token=authenticate_user(@director1)

    # Test with missing branch name
    patch branch_url(@branch), params: { address: "Address One Updated" }, as: :json, headers: { "Authorization" => "Bearer #{access_token}" }
    assert_response :bad_request

    response_data = JSON.parse(@response.body)
    assert_equal "Branch name is required", JSON.parse(@response.body)["error"]
  end

  test "should return error if branch does not exist during update" do
    access_token=authenticate_user(@director1)

    non_existent_id = SecureRandom.uuid
    patch branch_url(non_existent_id), params: { name: "Branch-Organization 1 Updated", address: "Address One Updated" }, as: :json, headers: { "Authorization" => "Bearer #{access_token}" }
    assert_response :not_found

    response_data = JSON.parse(@response.body)
    assert_equal "Branch not found", response_data["error"]
  end

  test "should return error if branch with the same name already exists" do
    access_token=authenticate_user(@director1)

    # Test with existing branch name
    patch branch_url(@branch), params: { name: "Branch-Organization 2", address: "Address One Updated" }, as: :json, headers: { "Authorization" => "Bearer #{access_token}" }
    assert_response :bad_request

    response_data = JSON.parse(@response.body)
    assert_equal "Branch already exists with the name", response_data["error"]
  end

  test "should return error if update fails due to internal server error" do
    access_token=authenticate_user(@super_admin)

    # Simulate an internal server error by stubbing the `update` method to raise an error
    Branch.any_instance.stubs(:update!).raises(StandardError.new("Unexpected Error"))
    patch branch_url(@branch), params: { name: "Branch-Organization 1 Updated", address: "Address One Updated" }, as: :json, headers: { "Authorization" => "Bearer #{access_token}" }
    assert_response :internal_server_error

    response_data = JSON.parse(@response.body)
    assert_equal "An error occurred while updating branch, please try again", response_data["error"]
  end

  test "should delete branch successfully" do
    access_token=authenticate_user(@super_admin)

    assert_difference("Branch.count", -1) do
      delete branch_url(@branch2), as: :json, headers: { "Authorization" => "Bearer #{access_token}" }
    end

    assert_response :success
    assert_equal "Branch #{@branch2.name} deleted successfully", JSON.parse(@response.body)["message"]
  end

  test "should return error if branch does not exist during delete" do
    access_token=authenticate_user(@director1)

    non_existent_id = SecureRandom.uuid
    delete branch_url(non_existent_id), as: :json, headers: { "Authorization" => "Bearer #{access_token}" }
    assert_response :not_found

    response_data = JSON.parse(@response.body)
    assert_equal "Branch not found", response_data["error"]
  end

  test "should return error if branch has areas attached during delete" do
    access_token=authenticate_user(@super_admin)

    delete branch_url(@branch), as: :json, headers: { "Authorization" => "Bearer #{access_token}" }
    assert_response :bad_request

    response_data = JSON.parse(@response.body)
    assert_equal "Branch has areas, delete areas and then try again", response_data["error"]
  end

  test "should return error if delete fails due to internal server error" do
    access_token=authenticate_user(@director1)

    # Simulate an internal server error by stubbing the `destroy` method to raise an error
    Branch.any_instance.stubs(:destroy).raises(ActiveRecord::RecordNotDestroyed.new("Failed to delete"))

    delete branch_url(@branch2), as: :json, headers: { "Authorization" => "Bearer #{access_token}" }
    assert_response :internal_server_error

    response_data = JSON.parse(@response.body)
    assert_equal "An error occurred while deleting branch, please try again", response_data["error"]
  end
end
