class AddLargePopupToShippingEasyCredentials < ActiveRecord::Migration[5.1]
  def change
    add_column :shipping_easy_credentials, :large_popup, :boolean, default: true
  end
end
