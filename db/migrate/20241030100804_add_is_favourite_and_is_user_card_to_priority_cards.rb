class AddIsFavouriteAndIsUserCardToPriorityCards < ActiveRecord::Migration[6.1]
  def change
    add_column :priority_cards, :is_favourite, :boolean, default: false
    add_column :priority_cards, :is_user_card, :boolean, default: false
  end
end
