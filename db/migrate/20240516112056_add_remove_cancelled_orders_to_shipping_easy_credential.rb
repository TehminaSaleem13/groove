class AddRemoveCancelledOrdersToShippingEasyCredential < ActiveRecord::Migration[5.1]
  def change
    add_column :shipping_easy_credentials, :remove_cancelled_orders, :boolean, default: false
  end
end
