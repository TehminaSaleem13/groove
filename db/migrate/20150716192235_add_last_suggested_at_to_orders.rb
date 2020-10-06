class AddLastSuggestedAtToOrders < ActiveRecord::Migration[5.1]
  def change
    add_column :orders, :last_suggested_at, :datetime
  end
end
