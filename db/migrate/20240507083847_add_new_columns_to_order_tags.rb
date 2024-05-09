class AddNewColumnsToOrderTags < ActiveRecord::Migration[5.1]
  def change
    add_column :order_tags, :groovepacker_id, :string
    add_column :order_tags, :source_id, :string

    change_column :order_tags, :name, :string, limit: 25, null: false
    change_column :order_tags, :color, :string, default: '#B8B8B8', null: false
  end
end
