class AddUniqueIndexToEmployeesName < ActiveRecord::Migration[8.0]
  def change
    # Add a unique index on the 'email' column
    add_index :employees, :email, unique: true
  end
end
