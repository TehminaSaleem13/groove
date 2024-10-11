class AddIsCardStandByToPriorityCards < ActiveRecord::Migration[6.1]
  def change
    add_column :priority_cards, :is_stand_by, :boolean, default: false
  end
end
