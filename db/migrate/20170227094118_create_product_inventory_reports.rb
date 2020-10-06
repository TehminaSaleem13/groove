class CreateProductInventoryReports < ActiveRecord::Migration[5.1]
  def change
    create_table :product_inventory_reports do |t|
      t.string   :name
      t.boolean  :scheduled,    :default => false
      t.boolean  :type,         :default => false
      t.timestamps
    end
  end
end


