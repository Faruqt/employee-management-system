class CreateAreasBranches < ActiveRecord::Migration[8.0]
  def change
    create_table :areas_branches, id: :uuid do |t|
      t.references :area, type: :uuid, null: false, foreign_key: true
      t.references :branch, type: :uuid, null: false, foreign_key: true

      t.timestamps
    end

    # Add a unique index to enforce the many-to-many relationship and prevent duplicates
    add_index :areas_branches, [:area_id, :branch_id], unique: true
  end
end
