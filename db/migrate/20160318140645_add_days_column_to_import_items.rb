class AddDaysColumnToImportItems < ActiveRecord::Migration[5.1]
  def change
    add_column :import_items, :days, :integer
  end
end
