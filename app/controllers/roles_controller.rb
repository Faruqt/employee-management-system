class RolesController < ApplicationController
  # GET /roles
  def index
    begin
      # Default page is 1, and per_page is defined in constants.rb
      page = (params[:page] || 1).to_i
      # Ensure page is at least 1
      page = 1 if page < 1

      per_page = (params[:per_page] || Constants::DEFAULT_PER_PAGE).to_i
      per_page = Constants::DEFAULT_PER_PAGE if per_page < 1 # ensure per_page is a positive integer

      # Use kaminari's `page` and `per` methods to paginate
      roles = Role.page(page).per(per_page).order(created_at: :desc)

      # Construct next and previous page URLs
      next_page_url = roles.next_page ? url_for(page: roles.next_page, per_page: per_page) : nil
      prev_page_url = roles.prev_page ? url_for(page: roles.prev_page, per_page: per_page) : nil

      Rails.logger.info("Fetched roles successfully")
      render json: {
        roles: roles.map(&:public_attributes),
        meta: {
          current_page: roles.current_page,
          total_pages: roles.total_pages,
          total_count: roles.total_count,
          next_page: next_page_url,
          prev_page: prev_page_url
        }
      }, status: :ok
    rescue StandardError => e
      Rails.logger.error("Unexpected error: #{e.message}")
      render json: { error: "An error occurred while fetching roles, please try again"}, status: :internal_server_error
    end
  end

  # GET /roles/:id
  def show
    id = params[:id]

    if id.blank?
      render json: { error: "Role ID is required" }, status: :bad_request
      return
    end

    begin
      role = Role.find_by(id: id)
      unless role
        Rails.logger.error("Role not found with ID: #{id}")
        render json: { error: "Role not found" }, status: :not_found
        return
      end

      Rails.logger.info("Fetched role successfully")
      render json: { role: role.public_attributes }, status: :ok
    rescue StandardError => e
      Rails.logger.error("Unexpected error: #{e.message}")
      render json: { error: "An error occurred while fetching role, please try again" }, status: :internal_server_error
    end
  end

  def create
    name = params[:name]
    symbol = params[:symbol]
    area_id = params[:area_id]

    if name.blank?
      render json: { error: "Name is required" }, status: :bad_request
      return
    end

    if symbol.blank?
      render json: { error: "Symbol is required" }, status: :bad_request
      return
    end 

    if area_id.blank?
      render json: { error: "Area ID is required" }, status: :bad_request
      return
    end

    begin
      # check if area exists
      area = Area.find_by(id: area_id)
      unless area
        Rails.logger.error("Area not found with ID: #{area_id}")
        render json: { error: "Area not found" }, status: :not_found
        return
      end

      # check if role already exists in the area
      role = Role.find_by(name: name, area_id: area_id)
      if role
        Rails.logger.error("Role already exists with name: #{name}")
        render json: { error: "Role already exists with the name" }, status: :bad_request
        return
      end

      role = Role.create!(name: name, symbol: symbol, area_id: area_id)

      Rails.logger.info("Role #{role.id} created successfully")
      render json: { role: role.public_attributes, message: "Role created successfully" }, status: :created
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error("An error occured while creating role : #{e.message}")
      render json: { error: "An error occurred while creating role, please try again"}, status: :bad_request
    rescue StandardError => e
      Rails.logger.error("Unexpected error: #{e.message}")
      render json: { error: "An error occurred while creating role, please try again" }, status: :internal_server_error
    end
  end

  # PATCH /roles/:id
  def update
    id = params[:id]
    name = params[:name]
    symbol = params[:symbol]

    if id.blank?
      render json: { error: "Role ID is required" }, status: :bad_request
      return
    end

    if name.blank?
      render json: { error: "Name is required" }, status: :bad_request
      return
    end

    if symbol.blank?
      render json: { error: "Symbol is required" }, status: :bad_request
      return
    end

    begin
      role = Role.find_by(id: id)
      unless role
        Rails.logger.error("Role not found with ID: #{id}")
        render json: { error: "Role not found" }, status: :not_found
        return
      end

      # check if role already exists with the name in the same area
      existing_role = Role.find_by(name: name, area_id: role.area_id)
      if existing_role && existing_role.id != role.id
        Rails.logger.error("Role already exists with name: #{name}")
        render json: { error: "Role already exists with the name" }, status: :bad_request
        return
      end

      # Update the role
      role.update!(name: name, symbol: symbol)
      
      Rails.logger.info("Role #{id} updated successfully")
      render json: { role: role.public_attributes, message: "Role updated successfully" }, status: :ok

    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error("An error occured while updating role : #{e.message}")
      render json: { error: "An error occurred while updating role, please try again"}, status: :bad_request
    rescue StandardError => e
      Rails.logger.error("Unexpected error: #{e.message}")
      render json: { error: "An error occurred while updating role, please try again" }, status: :internal_server_error
    end
  end

  # DELETE /roles/:id
  def destroy
    id = params[:id]

    if id.blank?
      render json: { error: "Role ID is required" }, status: :bad_request
      return
    end

    begin
      role = Role.find_by(id: id)
      unless role
        Rails.logger.error("Role not found with ID: #{id}")
        render json: { error: "Role not found" }, status: :not_found
        return
      end

      # TODO: check if role is attached to any employee
      
      role.destroy

      Rails.logger.info("Role #{id} deleted successfully")
      render json: { message: "Role #{role.name} deleted successfully" }, status: :ok

    rescue StandardError => e
      Rails.logger.error("Unexpected error: #{e.message}")
      render json: { error: "An error occurred while deleting role, please try again" }, status: :internal_server_error
    rescue ActiveRecord::RecordNotDestroyed => e
      Rails.logger.error("Error deleting role: #{e.message}")
      render json: { error: "An error occurred while deleting role, please try again" }, status: :internal_server_error
    end
  end
end
