class AddColumnsToCsvMapping < ActiveRecord::Migration
  def change
    add_column :csv_mappings, :product_csv_map_id, :integer
    add_column :csv_mappings, :order_csv_map_id, :integer
  end
end
