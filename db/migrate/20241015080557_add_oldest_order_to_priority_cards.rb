class AddOldestOrderToPriorityCards < ActiveRecord::Migration[6.1]
  def change
    add_column :priority_cards, :oldest_order, :datetime
  end
end
