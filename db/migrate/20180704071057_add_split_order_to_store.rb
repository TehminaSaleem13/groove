class AddSplitOrderToStore < ActiveRecord::Migration[5.1]
  def change
    add_column :stores, :split_order, :boolean, :default => false
  end
end
