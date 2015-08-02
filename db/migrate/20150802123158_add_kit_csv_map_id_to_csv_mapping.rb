class AddKitCsvMapIdToCsvMapping < ActiveRecord::Migration
  def change
    add_column :csv_mappings, :kit_csv_map_id, :integer
  end
end
