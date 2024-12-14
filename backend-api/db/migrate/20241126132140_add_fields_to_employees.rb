class AddFieldsToEmployees < ActiveRecord::Migration[7.2]
  def change
    add_column :employees, :is_deleted, :boolean
    add_column :employees, :date_of_birth, :date
    add_column :employees, :contract_start_date, :date
    add_column :employees, :contract_end_date, :date
  end
end
