class AddSplitOrderToStore < ActiveRecord::Migration
  def change
    add_column :stores, :split_order, :boolean, :default => false
  end
end
