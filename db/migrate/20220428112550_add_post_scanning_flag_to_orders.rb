class AddPostScanningFlagToOrders < ActiveRecord::Migration[5.1]
  def change
    add_column :orders, :post_scanning_flag, :string, default: nil
  end
end
