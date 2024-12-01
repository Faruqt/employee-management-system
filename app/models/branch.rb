class Branch < ApplicationRecord
    # Custom method for public attributes
    def public_attributes
        {
            id: id,
            name: name,
            address: address,
            organization_id: organization_id,
            created_at: created_at.strftime(Constants::DATETIME_FORMAT),
            updated_at: updated_at.strftime(Constants::DATETIME_FORMAT)
        }
    end

    # Many-to-Many relationship with Areas
    has_and_belongs_to_many :areas, join_table: :areas_branches

    # Association with Organization
    belongs_to :organization
end
