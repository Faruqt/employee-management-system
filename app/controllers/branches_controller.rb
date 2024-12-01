class BranchesController < ApplicationController
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

    if name.blank?
      render json: { error: "Branch name is required" }, status: :bad_request
      return
    end

    if organization_id.blank?
      render json: { error: "Organization ID is required" }, status: :bad_request
      return
    end

    begin
      # check if branch name already exists in the organization
      branch = Branch.find_by(name: name, organization_id: organization_id)
      if branch
        Rails.logger.error("Branch already exists with name: #{name}")
        render json: { error: "Branch already exists with the name" }, status: :bad_request
        return
      end

      branch = Branch.create!(name: name, address: address, organization_id: organization_id)

      Rails.logger.info("Branch created successfully")
      render json: { branch: branch.public_attributes, message: "Branch created successfully" }, status: :created
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error("Validation error: #{e.message}")
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

    if id.blank?
      render json: { error: "Branch ID is required" }, status: :bad_request
      return
    end

    if name.blank?
      render json: { error: "Branch name is required" }, status: :bad_request
      return
    end

    begin
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
