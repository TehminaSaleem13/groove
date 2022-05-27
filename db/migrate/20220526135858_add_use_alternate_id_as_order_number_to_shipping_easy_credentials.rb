class AddUseAlternateIdAsOrderNumberToShippingEasyCredentials < ActiveRecord::Migration[5.1]
  def change
    add_column :shipping_easy_credentials, :use_alternate_id_as_order_num, :boolean, default: false
  end
end
