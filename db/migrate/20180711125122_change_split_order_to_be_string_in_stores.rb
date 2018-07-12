class ChangeSplitOrderToBeStringInStores < ActiveRecord::Migration
  def up
    change_column :stores, :split_order, :string, :default => "disabled"
  end

  def down
    change_column :stores, :split_order, :boolean, :default => false
  end
end
