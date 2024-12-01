class Organization < ApplicationRecord
    # Custom method for public attributes
    def public_attributes
        {
            id: id,
            name: name,
            address: address,
            created_at: created_at.strftime(Constants::DATETIME_FORMAT),
            updated_at: updated_at.strftime(Constants::DATETIME_FORMAT)
        }
    end

    # One to Many relationship with Branches
    has_many :branches, dependent: :restrict_with_error
end
