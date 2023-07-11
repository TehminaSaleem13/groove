class ChangeColumnValueToImportItem < ActiveRecord::Migration[5.1]
  def change
    change_column_default :import_items, :updated_orders_import, from: nil, to: 0
  end
end
