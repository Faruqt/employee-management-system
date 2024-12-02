class CreateAdmins < ActiveRecord::Migration[8.0]
  def change
    create_table :admins, id: :uuid do |t|
      t.string :first_name
      t.string :last_name
      t.string :email
      t.string :telephone
      t.boolean :is_deleted
      t.boolean :is_manager
      t.boolean :is_director
      t.boolean :is_super_admin

      t.timestamps

      # Add a foreign key to the branches and areas table
      t.references :branch, type: :uuid, foreign_key: true
      t.references :area, type: :uuid, foreign_key: true
    end
  end
end
