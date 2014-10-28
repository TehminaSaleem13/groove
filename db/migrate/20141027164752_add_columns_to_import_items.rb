class AddColumnsToImportItems < ActiveRecord::Migration
  def change
    add_column :import_items, :to_import, :integer, :default => 0
    add_column :import_items, :current_increment_id, :string, :default => ''
    add_column :import_items, :current_order_items, :integer, :default => 0
    add_column :import_items, :current_order_imported_item, :integer, :default => 0
    add_column :import_items, :message, :string, :default => ''
  end
end
