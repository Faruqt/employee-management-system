require "test_helper"

class AreasControllerTest < ActionDispatch::IntegrationTest
  def setup
    setup_test_data
    setup_cognito_mock

    # Create extra test data
    @area2 = Area.create!(name: "Area Two", color: "Color Two")
    @area3 = Area.create!(name: "Area Three", color: "Color Three")
    @area4 = Area.create!(name: "Area Four", color: "Color Four")
    @branch2 = Branch.create!(name: "Branch Two", address: "Branch Address Two", organization: @org)
    @branch2.areas << @area2
  end

  def authenticate_user(user)
    setup_cognito_mock_for_authentication(user.email)

    session = setup_authenticated_session(user)

    access_token = session[:access_token]

    access_token
  end

  test "should return paginated areas" do
    # Test with default pagination

    access_token=authenticate_user(@manager)

    get areas_url, as: :json, headers: { "Authorization" => "Bearer #{access_token}" }
    assert_response :success

    response_data = JSON.parse(@response.body)
    areas = response_data["areas"]
    meta = response_data["meta"]

    assert_equal 4, meta["total_count"]
    assert_equal 1, meta["current_page"]
    assert_not_nil meta["total_pages"]
    assert_equal "Area Four", areas.first["name"] # Ordered by created_at: desc
    assert_equal "Color Four", areas.first["color"]
  end

  test "should handle custom pagination parameters" do
    # Test with custom page and per_page parameters
    access_token=authenticate_user(@director)

    get areas_url, params: { page: 1, per_page: 2 }, as: :json, headers: { "Authorization" => "Bearer #{access_token}" }
    assert_response :success

    response_data = JSON.parse(@response.body)
    areas = response_data["areas"]
    meta = response_data["meta"]

    assert_equal 2, areas.size
    assert_equal 1, meta["current_page"]
    assert_equal 2, meta["total_pages"]
    assert_not_nil meta["next_page"]
  end

  test "should return empty areas list for out-of-range page" do
    access_token=authenticate_user(@super_admin)

    get areas_url, params: { page: 5, per_page: 2 }, as: :json, headers: { "Authorization" => "Bearer #{access_token}" }
    assert_response :success

    response_data = JSON.parse(@response.body)
    areas = response_data["areas"]
    meta = response_data["meta"]

    assert_empty areas
    assert_equal 5, meta["current_page"]
    assert_equal 2, meta["total_pages"]
  end

  test "should return correct next and previous page URLs" do
    access_token=authenticate_user(@manager)

    # Test the next and prev URLs
    get areas_url, params: { page: 1, per_page: 2 }, as: :json, headers: { "Authorization" => "Bearer #{access_token}" }
    assert_response :success

    response_data = JSON.parse(@response.body)
    meta = response_data["meta"]

    assert_not_nil meta["next_page"]
    assert_nil meta["prev_page"]
  end

  test "should return area details when valid ID is provided" do
    access_token=authenticate_user(@director)

    get area_url(@area), as: :json, headers: { "Authorization" => "Bearer #{access_token}" }
    assert_response :success

    response_data = JSON.parse(@response.body)
    area = response_data["area"]

    assert_equal "Area One", area["name"]
    assert_equal "Color One", area["color"]
  end

  test "should return error when invalid ID is provided" do
    access_token=authenticate_user(@director)

    non_existent_id = SecureRandom.uuid
    get area_url(non_existent_id), as: :json, headers: { "Authorization" => "Bearer #{access_token}" }

    assert_response :not_found
    response_data = JSON.parse(@response.body)
    assert_equal "Area not found", response_data["error"]
  end

  test "should return 500 internal server error on unexpected error" do
    access_token=authenticate_user(@director)

    # Simulate unexpected error by stubbing the Area.find_by method to raise an error
    Area.stubs(:find_by).raises(StandardError.new("Unexpected error"))

    get area_url(@area), as: :json, headers: { "Authorization" => "Bearer #{access_token}" }
    assert_response :internal_server_error
    response_data = JSON.parse(@response.body)
    assert_equal "An error occurred while fetching area, please try again", response_data["error"]
  end

  test "should create a new area" do
    access_token=authenticate_user(@director)

    # Simulate a successful area creation

    post areas_url, params: { name: "AreaT", color: "ColorT" }, as: :json, headers: { "Authorization" => "Bearer #{access_token}" }
    assert_response :created

    response_data = JSON.parse(@response.body)
    area = response_data["area"]

    assert_equal "AreaT", area["name"]
    assert_equal "ColorT", area["color"]

    # Check if the area was created in the database
    area = Area.find_by(name: "Area Four")
    assert_not_nil area
  end

  test "manager cannot create a new area" do
    access_token=authenticate_user(@manager)

    post areas_url, params: { name: "Area Four", color: "Color Four" }, as: :json, headers: { "Authorization" => "Bearer #{access_token}" }
    assert_response :unauthorized

    response_data = JSON.parse(@response.body)

    assert_equal "You are not authorized to perform this action", response_data["message"]
  end

  test "should return error when name is missing" do
    access_token=authenticate_user(@director)

    post areas_url, params: { color: "Color Four" }, as: :json, headers: { "Authorization" => "Bearer #{access_token}" }
    assert_response :bad_request

    response_data = JSON.parse(@response.body)
    assert_equal "Name is required", response_data["error"]
  end

  test "should return error when color is missing" do
    access_token=authenticate_user(@director)

    post areas_url, params: { name: "Area Four" }, as: :json, headers: { "Authorization" => "Bearer #{access_token}" }
    assert_response :bad_request

    response_data = JSON.parse(@response.body)
    assert_equal "Color is required", response_data["error"]
  end

  test "should return error when name is already taken" do
    access_token=authenticate_user(@director)

    post areas_url, params: { name: "Area One", color: "Color Four" }, as: :json, headers: { "Authorization" => "Bearer #{access_token}" }
    assert_response :bad_request

    response_data = JSON.parse(@response.body)
    assert_equal "Area already exists with the name", response_data["error"]
  end

  test "should update area with valid parameters" do

    access_token=authenticate_user(@director)
    patch area_url(@area2), params: { name: "Updated Area", color: "Updated Color" }, as: :json, headers: { "Authorization" => "Bearer #{access_token}" }
    assert_response :success

    response_data = JSON.parse(@response.body)
    area = response_data["area"]

    assert_equal "Updated Area", area["name"]
    assert_equal "Updated Color", area["color"]
  end

  test "should return error when name is missing during update" do

    access_token=authenticate_user(@director)
    patch area_url(@area2), params: { color: "Updated Color" }, as: :json, headers: { "Authorization" => "Bearer #{access_token}" }
    assert_response :bad_request

    response_data = JSON.parse(@response.body)
    assert_equal "Name is required", response_data["error"]
  end

  test "should return error when color is missing during update" do

    access_token=authenticate_user(@director)
    patch area_url(@area2), params: { name: "Updated Area" }, as: :json, headers: { "Authorization" => "Bearer #{access_token}" }
    assert_response :bad_request

    response_data = JSON.parse(@response.body)
    assert_equal "Color is required", response_data["error"]
  end

  test "should return error if update fails due to internal server error" do
    access_token=authenticate_user(@director)
    # Simulate an error during area update
    Area.any_instance.stubs(:update!).raises(StandardError.new("Unexpected error"))

    patch area_url(@area2), params: { name: "Updated Area", color: "Updated Color" }, as: :json, headers: { "Authorization" => "Bearer #{access_token}" }
    assert_response :internal_server_error

    response_data = JSON.parse(@response.body)
    assert_equal "An error occurred while updating area, please try again", response_data["error"]
  end

  test "should delete area successfully" do
    access_token=authenticate_user(@director)
    assert_difference("Area.count", -1) do
      delete area_url(@area3), as: :json, headers: { "Authorization" => "Bearer #{access_token}" }
    end

    assert_response :success
    assert_equal "Area #{@area3.name} deleted successfully", JSON.parse(@response.body)["message"]
  end

  test "should return error when area does not exist" do
    access_token=authenticate_user(@director)
    non_existent_id = SecureRandom.uuid
    delete area_url(non_existent_id), as: :json, headers: { "Authorization" => "Bearer #{access_token}" }
    assert_response :not_found

    response_data = JSON.parse(@response.body)
    assert_equal "Area not found", response_data["error"]
  end

  test "should return error when area has branches attached" do
    access_token=authenticate_user(@director)
    delete area_url(@area2), as: :json, headers: { "Authorization" => "Bearer #{access_token}" }
    assert_response :bad_request

    response_data = JSON.parse(@response.body)
    assert_equal "Area has branches, detach from branches and then try again", response_data["error"]
  end

  test "should return error if delete fails due to internal server error" do
    access_token=authenticate_user(@director)
    # Simulate an error during area deletion
    Area.any_instance.stubs(:destroy).raises(StandardError.new("Unexpected error"))

    delete area_url(@area4), as: :json, headers: { "Authorization" => "Bearer #{access_token}" }
    assert_response :internal_server_error

    response_data = JSON.parse(@response.body)
    assert_equal "An error occurred while deleting area, please try again", response_data["error"]
  end
end
