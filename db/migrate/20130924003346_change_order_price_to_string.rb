class ChangeOrderPriceToString < ActiveRecord::Migration
  def up
  	change_column :orders, :price, :string
  end

  def down
  	change_column :orders, :price, :decimal
  end
end
