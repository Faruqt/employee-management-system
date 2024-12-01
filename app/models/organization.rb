class Organization < ApplicationRecord

    def public_attributes
        {
            id: id,
            name: name,
            address: address,
            created_at: created_at.strftime(Constants::DATETIME_FORMAT),
            updated_at: updated_at.strftime(Constants::DATETIME_FORMAT)
        }
    end
end
