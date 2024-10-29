class AddLotColumnToOrderSerial < ActiveRecord::Migration[6.1]
  def change
    add_column :order_serials, :lot, :string
    add_column :order_serials, :exp_date, :datetime
    add_column :order_serials, :bestbuy_date, :datetime
    add_column :order_serials, :mfg_date, :datetime
  end
end
