class AddDisplaySummaryColumnToOrderImportSummaries < ActiveRecord::Migration[5.1]
  def change
    add_column :order_import_summaries, :display_summary, :boolean, :default => false
  end
end
