class AddColumnToImportItem < ActiveRecord::Migration[5.1]
  def change
  	add_column :import_items, :import_error, :text
  end
end
