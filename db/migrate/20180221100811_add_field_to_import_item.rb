class AddFieldToImportItem < ActiveRecord::Migration[5.1]
  def change
  	add_column :import_items, :failed_count, :integer, :default=>0
  end
end
