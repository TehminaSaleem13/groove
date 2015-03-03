class CreateCsvMaps < ActiveRecord::Migration
  def change
    create_table :csv_maps do |t|
      t.string :kind
      t.string :name
      t.boolean :custom, :default =>true
      t.text :map

      t.timestamps
    end
  end
end
