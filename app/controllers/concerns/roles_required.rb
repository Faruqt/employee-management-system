module RolesRequired
  extend ActiveSupport::Concern

  private

  def roles_required(allowed_roles)
    # Check if current_user is present
    if @current_user.nil?
      render json: { message: "Unauthorized access" }, status: :unauthorized
      return
    end

    # Find the admin by email
    admin = Admin.find_by(email: @current_user["email"])

    # Check if the admin exists and if they have the required role
    unless admin && allowed_roles.any? { |role| admin.admin_type == role.to_s }
      Rails.logger.error("Unauthorized access by user: #{@current_user["email"]}")
      render json: { message: "You are not authorized to perform this action" }, status: :unauthorized
    end
  end
end
