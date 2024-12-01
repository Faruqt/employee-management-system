class Role < ApplicationRecord
    def public_attributes
        {
            id: id,
            name: name,
            symbol: symbol,
            area_id: area_id,
            created_at: created_at.strftime(Constants::DATETIME_FORMAT),
            updated_at: updated_at.strftime(Constants::DATETIME_FORMAT)
        }
    end
end
