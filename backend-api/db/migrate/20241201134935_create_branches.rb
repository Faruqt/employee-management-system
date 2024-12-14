class CreateBranches < ActiveRecord::Migration[8.0]
  def change
    create_table :branches, id: :uuid do |t|
      t.string :name
      t.string :address

      t.timestamps

      # Add a foreign key to the organizations table
      t.references :organization, type: :uuid, foreign_key: true
    end
  end
end
