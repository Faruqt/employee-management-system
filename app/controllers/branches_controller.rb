# BranchesController handles CRUD operations for Branches.
# 
# Actions:
# - index: Fetches a paginated list of branches.
# - show: Fetches details of a specific branch by ID.
# - create: Creates a new branch.
# - update: Updates an existing branch by ID.
# - destroy: Deletes a branch by ID.
# 
# Before Actions:
# - authenticate_user!: Ensures the user is authenticated.
# - roles_required(["super_admin"]): Ensures only super admins can access these routes.
# 
# Methods:
# - index: 
#   - Params: page (optional), per_page (optional)
#   - Returns: JSON response with paginated branches and metadata.
# - show: 
#   - Params: id (required)
#   - Returns: JSON response with branch details or error message.
# - create: 
#   - Params: name (required), address (optional), organization_id (required), areas_ids (optional)
#   - Returns: JSON response with created branch details or error message.
# - update: 
#   - Params: id (required), name (required), address (optional), areas_ids (optional)
#   - Returns: JSON response with updated branch details or error message.
# - destroy: 
#   - Params: id (required)
#   - Returns: JSON response with success message or error message.

class BranchesController < ApplicationController

  # Include the required concerns
  include AccessRequired
  include RolesRequired

  before_action :authenticate_user!

  # Ensure that only super admins can access these routes
  before_action -> { roles_required(["super_admin"]) }

  # GET /branches
  def index
    begin
      # Default page is 1, and per_page is defined in constants.rb
      page = (params[:page] || 1).to_i
      # Ensure page is at least 1
      page = 1 if page < 1

      per_page = (params[:per_page] || Constants::DEFAULT_PER_PAGE).to_i
      per_page = Constants::DEFAULT_PER_PAGE if per_page < 1 # ensure per_page is a positive integer

      # Use kaminari's `page` and `per` methods to paginate
      branches = Branch.page(page).per(per_page).order(created_at: :desc)

      # Construct next and previous page URLs
      next_page_url = branches.next_page ? url_for(page: branches.next_page, per_page: per_page) : nil
      prev_page_url = branches.prev_page ? url_for(page: branches.prev_page, per_page: per_page) : nil

      Rails.logger.info("Fetched branches successfully")
      render json: {
        branches: branches.map(&:public_attributes),
        meta: {
          current_page: branches.current_page,
          total_pages: branches.total_pages,
          total_count: branches.total_count,
          next_page: next_page_url,
          prev_page: prev_page_url
        }
      }, status: :ok
    rescue StandardError => e
      Rails.logger.error("Unexpected error: #{e.message}")
      render json: { error: "An error occurred while fetching branches, please try again" }, status: :internal_server_error
    end
  end

  # GET /branches/:id
  def show
    id = params[:id]

    if id.blank?
      render json: { error: "Branch ID is required" }, status: :bad_request
      return
    end

    begin
      branch = Branch.find_by(id: id)
      unless branch
        Rails.logger.error("Branch not found with ID: #{id}")
        render json: { error: "Branch not found" }, status: :not_found
        return
      end

      Rails.logger.info("Fetched branch successfully")
      render json: { branch: branch.public_attributes }, status: :ok
    rescue StandardError => e
      Rails.logger.error("Unexpected error: #{e.message}")
      render json: { error: "An error occurred while fetching branch, please try again" }, status: :internal_server_error
    end
  end

  # POST /branches
  def create
    name = params[:name]
    address = params[:address]
    organization_id = params[:organization_id]
    areas_ids = params[:areas_ids]

    if name.blank?
      render json: { error: "Branch name is required" }, status: :bad_request
      return
    end

    if organization_id.blank?
      render json: { error: "Organization ID is required" }, status: :bad_request
      return
    end

    begin

      if areas_ids
        # check that all area_ids are valid
        areas_ids.each do |area_id|
          area = Area.find_by(id: area_id)
          unless area
            Rails.logger.error("Area not found with ID: #{area_id}")
            render json: { error: "Area with id #{area_id} not found" }, status: :not_found
            return
          end
        end
      end

      # check if branch name already exists in the organization
      branch = Branch.find_by(name: name, organization_id: organization_id)
      if branch
        Rails.logger.error("Branch already exists with name: #{name}")
        render json: { error: "Branch already exists with the name" }, status: :bad_request
        return
      end

      # create the branch
      branch = Branch.create!(name: name, address: address, organization_id: organization_id)

      # attach the branch to the area if area_id is provided
      if areas_ids
        areas_ids.each do |area_id|
          area = Area.find_by(id: area_id)
          branch.areas << area
        end
      end

      Rails.logger.info("Branch created successfully")
      render json: { branch: branch.public_attributes, message: "Branch created successfully" }, status: :created
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error("An error occurred while creating branch: #{e.message}")
      render json: { error: "An error occurred while creating branch, please try again" }, status: :bad_request
    rescue StandardError => e
      Rails.logger.error("Unexpected error: #{e.message}")
      render json: { error: "An error occurred while creating branch, please try again" }, status: :internal_server_error
    end
  end

  # PATCH/PUT /branches/:id
  def update
    id = params[:id]
    name = params[:name]
    address = params[:address]
    areas_ids = params[:areas_ids]

    if id.blank?
      render json: { error: "Branch ID is required" }, status: :bad_request
      return
    end

    if name.blank?
      render json: { error: "Branch name is required" }, status: :bad_request
      return
    end

    begin
      if areas_ids
        # check that all area_ids are valid
        areas_ids.each do |area_id|
          area = Area.find_by(id: area_id)
          unless area
            Rails.logger.error("Area not found with ID: #{area_id}")
            render json: { error: "Area with id #{area_id} not found" }, status: :not_found
            return
          end
        end
      end

      branch = Branch.find_by(id: id)
      unless branch
        Rails.logger.error("Branch not found with ID: #{id}")
        render json: { error: "Branch not found" }, status: :not_found
        return
      end

      # Check for existing branch with the same name
      existing_branch = Branch.find_by(name: name)
      if existing_branch && existing_branch.id != branch.id
        Rails.logger.error("Branch already exists with name: #{name}")
        render json: { error: "Branch already exists with the name" }, status: :bad_request
        return
      end

      # Update the branch
      branch.update!(name: name, address: address)

      # attach the branch to the areas if areas_ids is provided
      if areas_ids
        # clear existing areas
        branch.areas.clear

        # attach the branch to the areas
        areas_ids.each do |area_id|
          area = Area.find_by(id: area_id)
          branch.areas << area
        end
      end

      Rails.logger.info("Branch updated successfully")
      render json: { branch: branch.public_attributes, message: "Branch updated successfully" }, status: :ok
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error("Updating branch failed: #{e.message}")
      render json: { error: "An error occurred while updating branch, please try again" }, status: :bad_request
    rescue StandardError => e
      Rails.logger.error("Unexpected error: #{e.message}")
      render json: { error: "An error occurred while updating branch, please try again" }, status: :internal_server_error
    end
  end

  # DELETE /branches/:id
  def destroy
    id = params[:id]

    if id.blank?
      render json: { error: "Branch ID is required" }, status: :bad_request
      return
    end

    begin
      branch = Branch.find_by(id: id)
      unless branch
        Rails.logger.error("Branch not found with ID: #{id}")
        render json: { error: "Branch not found" }, status: :not_found
        return
      end

      # check if branch has any attached areas
      if branch.areas.any?
        Rails.logger.error("Branch has areas, cannot delete")
        render json: { error: "Branch has areas, delete areas and then try again" }, status: :bad_request
        return
      end

      branch.destroy

      Rails.logger.info("Branch #{id} deleted successfully")
      render json: { message: "Branch #{branch.name} deleted successfully" }, status: :ok

    rescue ActiveRecord::RecordNotDestroyed => e
      Rails.logger.error("Error deleting branch: #{e.message}")
      render json: { error: "An error occurred while deleting branch, please try again" }, status: :internal_server_error
    rescue StandardError => e
      Rails.logger.error("Unexpected error: #{e.message}")
      render json: { error: "An error occurred while deleting branch, please try again" }, status: :internal_server_error
    end
  end
end
