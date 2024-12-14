class Admin < ApplicationRecord
    # Constants for admin types
    ADMIN_TYPES = {
        manager: "manager",
        director: "director",
        super_admin: "super_admin"
    }.freeze

    # Validations
    validates :first_name, presence: true
    validates :email, presence: true, uniqueness: true

    # Validation for admin_type only if it's being set
    validate :validate_admin_type, if: :admin_type?

    # Callbacks
    before_validation :downcase_email

    def public_attributes
        {
            id: id,
            first_name: first_name,
            last_name: last_name,
            email: email,
            telephone: telephone,
            admin_type: admin_type,
            is_deleted: is_deleted,
            area: area&.public_attributes,
            branch: branch&.public_attributes,
            created_at: created_at.strftime(Constants::DATETIME_FORMAT),
            updated_at: updated_at.strftime(Constants::DATETIME_FORMAT)
        }
    end

    def admin_type_name
        ADMIN_TYPES.key(admin_type).to_s.capitalize
    end

    def self.admin_types
        ADMIN_TYPES
    end


    private

    def downcase_email
        self.email = email.downcase if email.present?
    end

    def validate_admin_type
        unless ADMIN_TYPES.values.include?(admin_type)
            errors.add(:admin_type, "is not included in the list")
        end
    end

    # One to Many relationship with Branches
    # required for managers and directors
    # optional for super admins
    belongs_to :branch, optional: true


    # One to Many relationship with Areas
    # required for managers
    # optional for directors and super admins
    belongs_to :area, optional: true
end
