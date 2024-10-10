class CreatePriorityCards < ActiveRecord::Migration[6.1]
  def change
    create_table :priority_cards do |t|
      t.string :priority_name, null: false, default: 'regular'
      t.string :assigned_tag, default: ''
      t.integer :order_tagged_count, default: 0
      t.string :tag_color, null: false, default: '#587493'
      t.boolean :is_card_disabled, default: false

      t.timestamps
    end

    add_index :priority_cards, :priority_name, unique: true
    add_index :priority_cards, :assigned_tag, unique: true
  end
end
