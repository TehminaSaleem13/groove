class AddDisplaySummaryColumnToOrderImportSummaries < ActiveRecord::Migration
  def change
    add_column :order_import_summaries, :display_summary, :boolean, :default => false
  end
end
