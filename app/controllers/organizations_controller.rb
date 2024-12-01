class OrganizationsController < ApplicationController
  # GET /organizations
  def index
    begin
      # Default page is 1, and per_page is defined in constants.rb
      page = (params[:page] || 1).to_i
      # Ensure page is at least 1
      page = 1 if page < 1

      per_page = (params[:per_page] || Constants::DEFAULT_PER_PAGE).to_i
      per_page = Constants::DEFAULT_PER_PAGE if per_page < 1 # ensure per_page is a positive integer

      # Use kaminari's `page` and `per` methods to paginate
      organizations = Organization.page(page).per(per_page).order(created_at: :desc)

      # Construct next and previous page URLs
      next_page_url = organizations.next_page ? url_for(page: organizations.next_page, per_page: per_page) : nil
      prev_page_url = organizations.prev_page ? url_for(page: organizations.prev_page, per_page: per_page) : nil

      Rails.logger.info("Fetched organizations successfully")
      render json: {
        organizations: organizations.map(&:public_attributes),
        meta: {
          current_page: organizations.current_page,
          total_pages: organizations.total_pages,
          total_count: organizations.total_count,
          next_page: next_page_url,
          prev_page: prev_page_url
        }
      }, status: :ok
    rescue StandardError => e
      Rails.logger.error("Unexpected error: #{e.message}")
      render json: { error: "An error occurred while fetching organizations, please try again" }, status: :internal_server_error
    end
  end

  # GET /organizations/:id
  def show
    id = params[:id]

    if id.blank?
      render json: { error: "Organization ID is required" }, status: :bad_request
      return
    end

    begin
      organization = Organization.find_by(id: id)
      unless organization
        Rails.logger.error("Organization not found with ID: #{id}")
        render json: { error: "Organization not found" }, status: :not_found
        return
      end

      Rails.logger.info("Fetched organization successfully")
      render json: { organization: organization.public_attributes }, status: :ok
    rescue StandardError => e
      Rails.logger.error("Unexpected error: #{e.message}")
      render json: { error: "An error occurred while fetching organization, please try again" }, status: :internal_server_error
    end
  end

  # POST /organizations
  def create
    name = params[:name]
    address = params[:address]

    if name.blank?
      render json: { error: "Name is required" }, status: :bad_request
      return
    end

    begin
      # Check if organization already exists
      organization = Organization.find_by(name: name)
      if organization
        Rails.logger.error("Organization already exists with name: #{name}")
        render json: { error: "Organization already exists with the name" }, status: :bad_request
        return
      end

      organization = Organization.create!(name: name, address: address)

      Rails.logger.info("Organization created successfully")
      render json: { organization: organization }, status: :created
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: e.message }, status: :bad_request
    rescue StandardError => e
      Rails.logger.error("Unexpected error: #{e.message}")
      render json: { error: "An error occurred while creating organization, please try again" }, status: :internal_server_error
    end
  end

  # PATCH/PUT /organizations/:id
  def update
    id = params[:id]
    name = params[:name]
    address = params[:address]

    # Early validation of required fields
    if id.blank? || name.blank?
      render json: { error: "Organization ID and name are required" }, status: :bad_request
      return
    end

    begin
      # Fetch the organization
      organization = Organization.find_by(id: id)
      unless organization
        Rails.logger.error("Organization not found with ID: #{id}")
        render json: { error: "Organization not found" }, status: :not_found
        return
      end

      # Check for existing organization with the same name
      existing_organization = Organization.find_by(name: name)
      if existing_organization && existing_organization.id != organization.id
        Rails.logger.error("Organization already exists with name: #{name}")
        render json: { error: "An organization with this name already exists" }, status: :bad_request
        return
      end

      # Update the organization
      organization.update!(name: name, address: address)

      Rails.logger.info("Organization updated successfully")

      render json: { organization: organization, message: "Organization updated successfully" }, status: :ok
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error("Error updating organization: #{e.message}")
      render json: { error: "Failed to update organization, please try again" }, status: :internal_server_error
    rescue StandardError => e
      Rails.logger.error("Unexpected error: #{e.message}")
      render json: { error: "Failed to update organization, please try again" }, status: :internal_server_error
    end
  end

  # DELETE /organizations/:id
  def destroy
    id = params[:id]

    if id.blank?
      render json: { error: "Organization ID is required" }, status: :bad_request
      return
    end

    begin
      organization = Organization.find_by(id: id)
      unless organization
        Rails.logger.error("Organization not found with ID: #{id}")
        render json: { error: "Organization not found" }, status: :not_found
        return
      end

      # check if organization has any branches
      if organization.branches.any?
        Rails.logger.error("Organization has branches, cannot delete")
        render json: { error: "Organization has branches, delete branches and then try again" }, status: :bad_request
        return
      end

      organization.destroy

      Rails.logger.info("Organization #{id} deleted successfully")
      render json: { message: "Organization #{organization.name} deleted successfully" }, status: :ok
    rescue ActiveRecord::RecordNotDestroyed => e
      Rails.logger.error("Error deleting organization: #{e.message}")
      render json: { error: "Failed to delete organization, please try again" }, status: :internal_server_error
    rescue StandardError => e
      Rails.logger.error("Unexpected error: #{e.message}")
      render json: { error: "Failed to delete organization, please try again" }, status: :internal_server_error
    end
  end
end
