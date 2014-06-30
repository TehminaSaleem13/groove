class AddOrderImportSummaryRefToImportItems < ActiveRecord::Migration
  def change
    add_column :import_items, :order_import_summary_id, :integer
  end
end
