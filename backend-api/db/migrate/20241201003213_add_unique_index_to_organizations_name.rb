class AddUniqueIndexToOrganizationsName < ActiveRecord::Migration[8.0]
  def change
    # Add a unique index on the 'name' column
    add_index :organizations, :name, unique: true
  end
end
