class Admin < ApplicationRecord
    # Validations
    validates :first_name, presence: true
    validates :email, presence: true, uniqueness: true

    # Callbacks
    before_validation :downcase_email

    def public_attributes
        {
            id: id,
            first_name: first_name,
            last_name: last_name,
            email: email,
            telephone: telephone,
            is_manager: is_manager,
            is_director: is_director,
            is_deleted: is_deleted,
            is_super_admin: is_super_admin,
            area: area&.public_attributes,
            branch: branch&.public_attributes,
            created_at: created_at.strftime(Constants::DATETIME_FORMAT),
            updated_at: updated_at.strftime(Constants::DATETIME_FORMAT)
        }
    end

    private

    def downcase_email
        self.email = email.downcase if email.present?
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
