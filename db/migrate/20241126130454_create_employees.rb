class CreateEmployees < ActiveRecord::Migration[7.2]
  def change
    create_table :employees, id: :uuid do |t|
      t.string :first_name
      t.string :last_name
      t.string :email
      t.string :telephone
      t.boolean :is_active
      t.string :qr_code_url
      t.string :contract_code
      t.string :tax_code
      t.string :shift_code

      t.timestamps
    end
  end
end
