class ChangeNameInOrderTags < ActiveRecord::Migration[5.1]
  def change
    change_column :order_tags, :name, :string, limit: nil
  end
end
