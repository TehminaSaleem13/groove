class AddColumnsToCsvProductImport < ActiveRecord::Migration
  def change
    add_column :csv_product_imports, :success_imported, :integer, :default => 0
    add_column :csv_product_imports, :duplicate_file, :integer, :default => 0
    add_column :csv_product_imports, :duplicate_db, :integer, :default => 0
  end
end
