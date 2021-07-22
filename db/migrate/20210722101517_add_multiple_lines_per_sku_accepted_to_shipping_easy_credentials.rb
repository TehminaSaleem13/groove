class AddMultipleLinesPerSkuAcceptedToShippingEasyCredentials < ActiveRecord::Migration[5.1]
  def change
    add_column :shipping_easy_credentials, :multiple_lines_per_sku_accepted, :boolean, default: false
  end
end
