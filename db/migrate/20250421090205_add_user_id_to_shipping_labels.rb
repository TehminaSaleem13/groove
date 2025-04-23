class AddUserIdToShippingLabels < ActiveRecord::Migration[6.1]
  def change
    add_column :shipping_labels, :user_id, :integer, references: :users
  end
end
