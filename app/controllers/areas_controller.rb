class AreasController < ApplicationController
  # GET /areas
  def index
    begin
      # Default page is 1, and per_page is defined in constants.rb
      page = (params[:page] || 1).to_i
      # Ensure page is at least 1
      page = 1 if page < 1

      per_page = (params[:per_page] || Constants::DEFAULT_PER_PAGE).to_i
      per_page = Constants::DEFAULT_PER_PAGE if per_page < 1 # ensure per_page is a positive integer

      # Use kaminari's `page` and `per` methods to paginate
      areas = Area.page(page).per(per_page).order(created_at: :desc)

      # Construct next and previous page URLs
      next_page_url = areas.next_page ? url_for(page: areas.next_page, per_page: per_page) : nil
      prev_page_url = areas.prev_page ? url_for(page: areas.prev_page, per_page: per_page) : nil

      Rails.logger.info("Fetched areas successfully")
      render json: {
        areas: areas.map(&:public_attributes),
        meta: {
          current_page: areas.current_page,
          total_pages: areas.total_pages,
          total_count: areas.total_count,
          next_page: next_page_url,
          prev_page: prev_page_url
        }
      }, status: :ok
    rescue StandardError => e
      Rails.logger.error("Unexpected error: #{e.message}")
      render json: { error: "An error occurred while fetching areas, please try again" }, status: :internal_server_error
    end
  end

  # GET /areas/:id
  def show
    id = params[:id]

    if id.blank?
      render json: { error: "Area ID is required" }, status: :bad_request
      return
    end

    begin
      area = Area.find_by(id: id)
      unless area
        Rails.logger.error("Area not found with ID: #{id}")
        render json: { error: "Area not found" }, status: :not_found
        return
      end

      Rails.logger.info("Fetched area successfully")
      render json: { area: area.public_attributes }, status: :ok
    rescue StandardError => e
      Rails.logger.error("Unexpected error: #{e.message}")
      render json: { error: "An error occurred while fetching area, please try again" }, status: :internal_server_error
    end
  end

  def create
    name = params[:name]
    color = params[:color]
    if name.blank?
      render json: { error: "Name is required" }, status: :bad_request
      return
    end

    if color.blank?
      render json: { error: "Color is required" }, status: :bad_request
      return
    end

    begin
      # check if area already exists
      area = Area.find_by(name: name)
      if area
        Rails.logger.error("Area already exists with name: #{name}")
        render json: { error: "Area already exists with the name" }, status: :bad_request
        return
      end

      area = Area.create!(name: name, color: color)
      Rails.logger.info("Area created successfully")
      render json: { area: area.public_attributes, message: "Area created successfully" }, status: :created
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error("Validation failed: #{e.message}")
      render json: { error: e.message }, status: :bad_request
    rescue StandardError => e
      Rails.logger.error("Unexpected error: #{e.message}")
      render json: { error: "An error occurred while creating area, please try again" }, status: :internal_server_error
    end

  end

  # PATCH /areas/:id
  def update
    id = params[:id]
    name = params[:name]
    color = params[:color]

    if id.blank?
      render json: { error: "Area ID is required" }, status: :bad_request
      return
    end

    if name.blank?
      render json: { error: "Name is required" }, status: :bad_request
      return
    end

    if color.blank?
      render json: { error: "Color is required" }, status: :bad_request
      return
    end

    begin
      area = Area.find_by(id: id)
      unless area
        Rails.logger.error("Area not found with ID: #{id}")
        render json: { error: "Area not found" }, status: :not_found
        return
      end

      # check if area already exists
      existing_area = Area.find_by(name: name)
      if existing_area && existing_area.id != area.id
        Rails.logger.error("Area already exists with name: #{name}")
        render json: { error: "Area already exists with the name" }, status: :bad_request
        return
      end

      area.update!(name: name, color: color)

      Rails.logger.info("Area updated successfully")
      render json: { area: area.public_attributes, message: "Area updated successfully" }, status: :ok
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error("Updateing area failed: #{e.message}")
      render json: { error: "An error occurred while updating area, please try again" }, status: :bad_request
    rescue StandardError => e
      Rails.logger.error("Unexpected error: #{e.message}")
      render json: { error: "An error occurred while updating area, please try again" }, status: :internal_server_error
    end
  end

  # DELETE /areas/:id
  def destroy
    id = params[:id]

    if id.blank?
      render json: { error: "Area ID is required" }, status: :bad_request
      return
    end

    begin
      area = Area.find_by(id: id)
      unless area
        Rails.logger.error("Area not found with ID: #{id}")
        render json: { error: "Area not found" }, status: :not_found
        return
      end

      # check if area is attached to any branch
      if area.branches.any?
        Rails.logger.error("Area has branches, cannot delete")
        render json: { error: "Area has branches, detach from branches and then try again" }, status: :bad_request
        return
      end

      # check if area has any attached role
      if area.roles.any?
        Rails.logger.error("Area has roles, cannot delete")
        render json: { error: "Area has roles, delete roles and then try again" }, status: :bad_request
        return
      end
      
      # delete the area
      area.destroy

      Rails.logger.info("Area #{id} deleted successfully")
      render json: { message: "Area #{area.name} deleted successfully" }, status: :ok
    rescue ActiveRecord::RecordNotDestroyed => e
      Rails.logger.error("Error deleting area: #{e.message}")
      render json: { error: "An error occurred while deleting area, please try again" }, status: :internal_server_error
    rescue StandardError => e
      Rails.logger.error("Unexpected error: #{e.message}")
      render json: { error: "An error occurred while deleting area, please try again" }, status: :internal_server_error
    end
  end
end
