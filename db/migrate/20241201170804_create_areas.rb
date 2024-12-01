class CreateAreas < ActiveRecord::Migration[8.0]
  def change
    create_table :areas, id: :uuid  do |t|
      t.string :name
      t.string :color

      t.timestamps
    end
  end
end
