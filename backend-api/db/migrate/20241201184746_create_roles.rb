class CreateRoles < ActiveRecord::Migration[8.0]
  def change
    create_table :roles, id: :uuid do |t|
      t.string :name
      t.string :symbol

      t.timestamps

      # Add a foreign key to the areas table
      t.references :area, type: :uuid, foreign_key: true
    end
  end
end
