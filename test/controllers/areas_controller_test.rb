require "test_helper"

class AreasControllerTest < ActionDispatch::IntegrationTest
  def setup
    # Create test data
    @area1 = Area.create!(name: "Area One", color: "Color One")
    @area2 = Area.create!(name: "Area Two", color: "Color Two")
    @area3 = Area.create!(name: "Area Three", color: "Color Three")
  end

  test "should return paginated areas" do
    # Test with default pagination
    get areas_url, as: :json
    assert_response :success

    response_data = JSON.parse(@response.body)
    areas = response_data["areas"]
    meta = response_data["meta"]

    assert_equal 3, meta["total_count"]
    assert_equal 1, meta["current_page"]
    assert_not_nil meta["total_pages"]
    assert_equal "Area Three", areas.first["name"] # Ordered by created_at: desc
    assert_equal "Color Three", areas.first["color"]
  end

  test "should handle custom pagination parameters" do
    # Test with custom page and per_page parameters
    get areas_url, params: { page: 1, per_page: 2 }, as: :json
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
    get areas_url, params: { page: 5, per_page: 2 }, as: :json
    assert_response :success

    response_data = JSON.parse(@response.body)
    areas = response_data["areas"]
    meta = response_data["meta"]

    assert_empty areas
    assert_equal 5, meta["current_page"]
    assert_equal 2, meta["total_pages"]
  end

  test "should return correct next and previous page URLs" do
    # Test the next and prev URLs
    get areas_url, params: { page: 1, per_page: 2 }, as: :json
    assert_response :success

    response_data = JSON.parse(@response.body)
    meta = response_data["meta"]

    assert_not_nil meta["next_page"]
    assert_nil meta["prev_page"]
  end

  test "should return area details when valid ID is provided" do
    get area_url(@area1), as: :json
    assert_response :success

    response_data = JSON.parse(@response.body)
    area = response_data["area"]

    assert_equal "Area One", area["name"]
    assert_equal "Color One", area["color"]
  end

  test "should return error when invalid ID is provided" do
    non_existent_id = SecureRandom.uuid
    get area_url(non_existent_id), as: :json

    assert_response :not_found
    response_data = JSON.parse(@response.body)
    assert_equal "Area not found", response_data["error"]
  end

  test "should return 500 internal server error on unexpected error" do
    # Simulate unexpected error by stubbing the Area.find_by method to raise an error
    Area.stubs(:find_by).raises(StandardError.new("Unexpected error"))

    get area_url(@area1), as: :json
    assert_response :internal_server_error
    response_data = JSON.parse(@response.body)
    assert_equal "An error occurred while fetching area, please try again", response_data["error"]
  end

  test "should create a new area" do
    # Simulate a successful area creation

    post areas_url, params: { name: "Area Four", color: "Color Four" }, as: :json
    assert_response :created

    response_data = JSON.parse(@response.body)
    area = response_data["area"]

    assert_equal "Area Four", area["name"]
    assert_equal "Color Four", area["color"]

    # Check if the area was created in the database
    area = Area.find_by(name: "Area Four")
    assert_not_nil area
  end

  test "should return error when name is missing" do
    post areas_url, params: { color: "Color Four" }, as: :json
    assert_response :bad_request

    response_data = JSON.parse(@response.body)
    assert_equal "Name is required", response_data["error"]
  end

  test "should return error when color is missing" do
    post areas_url, params: { name: "Area Four" }, as: :json
    assert_response :bad_request

    response_data = JSON.parse(@response.body)
    assert_equal "Color is required", response_data["error"]
  end

  test "should return error when name is already taken" do
    post areas_url, params: { name: "Area One", color: "Color Four" }, as: :json
    assert_response :bad_request

    response_data = JSON.parse(@response.body)
    assert_equal "Area already exists with the name", response_data["error"]
  end

  test "should update area with valid parameters" do
    patch area_url(@area1), params: { name: "Updated Area", color: "Updated Color" }, as: :json
    assert_response :success

    response_data = JSON.parse(@response.body)
    area = response_data["area"]

    assert_equal "Updated Area", area["name"]
    assert_equal "Updated Color", area["color"]
  end

  test "should return error when name is missing during update" do
    patch area_url(@area1), params: { color: "Updated Color" }, as: :json
    assert_response :bad_request

    response_data = JSON.parse(@response.body)
    assert_equal "Name is required", response_data["error"]
  end

  test "should return error when color is missing during update" do
    patch area_url(@area1), params: { name: "Updated Area" }, as: :json
    assert_response :bad_request

    response_data = JSON.parse(@response.body)
    assert_equal "Color is required", response_data["error"]
  end

  test "should return error if update fails due to internal server error" do
    # Simulate an error during area update
    Area.any_instance.stubs(:update!).raises(StandardError.new("Unexpected error"))

    patch area_url(@area1), params: { name: "Updated Area", color: "Updated Color" }, as: :json
    assert_response :internal_server_error

    response_data = JSON.parse(@response.body)
    assert_equal "An error occurred while updating area, please try again", response_data["error"]
  end

  test "should delete area successfully" do
    assert_difference("Area.count", -1) do
      delete area_url(@area1), as: :json
    end

    assert_response :success
    assert_equal "Area #{@area1.name} deleted successfully", JSON.parse(@response.body)["message"]
  end

  test "should return error when area does not exist" do
    non_existent_id = SecureRandom.uuid
    delete area_url(non_existent_id), as: :json
    assert_response :not_found

    response_data = JSON.parse(@response.body)
    assert_equal "Area not found", response_data["error"]
  end

  test "should return error if delete fails due to internal server error" do
    # Simulate an error during area deletion
    Area.any_instance.stubs(:destroy).raises(StandardError.new("Unexpected error"))

    delete area_url(@area1), as: :json
    assert_response :internal_server_error

    response_data = JSON.parse(@response.body)
    assert_equal "An error occurred while deleting area, please try again", response_data["error"]
  end
end
