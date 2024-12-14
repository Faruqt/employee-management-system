class AddDefaultToIsDeletedAndIsActiveInEmployees < ActiveRecord::Migration[8.0]
  def change
    change_column_default :employees, :is_deleted, from: nil, to: false
    change_column_default :employees, :is_active, from: nil, to: true
  end
end
