class AddNewSwitchToShippingEasyCredential < ActiveRecord::Migration[5.1]
  def change
    add_column :shipping_easy_credentials, :import_shipped_having_tracking, :boolean, default: false
  end
end
