class Branch < ApplicationRecord
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

    has_and_belongs_to_many :areas, join_table: :areas_branches
end
