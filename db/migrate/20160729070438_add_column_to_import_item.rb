class AddColumnToImportItem < ActiveRecord::Migration
  def change
  	add_column :import_items, :import_error, :text
  end
end
