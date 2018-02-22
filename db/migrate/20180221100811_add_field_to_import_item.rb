class AddFieldToImportItem < ActiveRecord::Migration
  def change
  	add_column :import_items, :failed_count, :integer, :default=>0
  end
end
