class Employee < ApplicationRecord
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
            is_active: is_active,
            qr_code_url: qr_code_url,
            contract_code: contract_code,
            tax_code: tax_code,
            shift_code: shift_code,
            is_deleted: is_deleted,
            date_of_birth: date_of_birth.strftime(Constants::DATE_FORMAT),
            contract_start_date: contract_start_date.strftime(Constants::DATE_FORMAT),
            contract_end_date: contract_end_date.strftime(Constants::DATE_FORMAT),
            created_at: created_at.strftime(Constants::DATETIME_FORMAT),
            updated_at: updated_at.strftime(Constants::DATETIME_FORMAT)
        }
    end

    private

    def downcase_email
        self.email = email.downcase if email.present?
    end
end
