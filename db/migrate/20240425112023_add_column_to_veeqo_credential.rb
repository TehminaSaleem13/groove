class AddColumnToVeeqoCredential < ActiveRecord::Migration[5.1]
  def change
    add_column :veeqo_credentials, :product_source_shopify_store_id, :integer
    add_column :veeqo_credentials, :use_shopify_as_product_source_switch, :boolean, default: false
  end
end
