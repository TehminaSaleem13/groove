class ChangeOrderPriceToString < ActiveRecord::Migration[5.1]
  def up
  	change_column :orders, :price, :string
  end

  def down
  	change_column :orders, :price, :decimal
  end
end
