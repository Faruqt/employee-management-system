class AddBranchesAndAreasForeignKeysToEmployees < ActiveRecord::Migration[8.0]
  def change
    add_reference :employees, :branch, type: :uuid, foreign_key: true
    add_reference :employees, :area, type: :uuid, foreign_key: true
  end
end
