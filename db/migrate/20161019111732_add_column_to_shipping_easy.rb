class AddColumnToShippingEasy < ActiveRecord::Migration[5.1]
  def change
  	add_column :shipping_easy_credentials, :popup_shipping_label, :boolean, :default => false 
  end
end
