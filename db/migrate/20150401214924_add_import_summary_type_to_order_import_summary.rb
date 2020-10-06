class AddImportSummaryTypeToOrderImportSummary < ActiveRecord::Migration[5.1]
  def change
    add_column :order_import_summaries, :import_summary_type, :string, default: "import_orders"
  end
end
