class AddImporterIdToOrders < ActiveRecord::Migration[5.1]
  def change
    add_column :orders, :importer_id, :string
  end
end
