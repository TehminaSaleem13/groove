class AddSuccessUpdatedToCsvProductImport < ActiveRecord::Migration
  def change
    add_column :csv_product_imports, :success_updated, :integer, :default => 0
  end
end
