class AddLastSuggestedAtToOrders < ActiveRecord::Migration
  def change
    add_column :orders, :last_suggested_at, :datetime
  end
end
