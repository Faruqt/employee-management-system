class Area < ApplicationRecord
    # Custom method for public attributes
    def public_attributes
        {
            id: id,
            name: name,
            color: color,
            created_at: created_at.strftime(Constants::DATETIME_FORMAT),
            updated_at: updated_at.strftime(Constants::DATETIME_FORMAT)
        }
    end

    # Many-to-Many relationship with Branches
    has_and_belongs_to_many :branches, join_table: :areas_branches

    # One to Many relationship with Roles
    has_many :roles, dependent: :restrict_with_error

    # One to Many relationship with Admins
    has_many :admins, dependent: :restrict_with_error
end
