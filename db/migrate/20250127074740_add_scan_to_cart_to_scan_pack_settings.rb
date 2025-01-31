class AddScanToCartToScanPackSettings < ActiveRecord::Migration[6.1]
  def change
    add_column :scan_pack_settings, :scan_to_cart_option, :boolean, default: false
  end
end
