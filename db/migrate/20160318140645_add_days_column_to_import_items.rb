class AddDaysColumnToImportItems < ActiveRecord::Migration
  def change
    add_column :import_items, :days, :integer
  end
end
