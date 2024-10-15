class AddPositionToPriorityCards < ActiveRecord::Migration[6.1]
  def change
    add_column :priority_cards, :position, :integer
  end
end
