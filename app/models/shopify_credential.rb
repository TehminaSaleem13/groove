class ShopifyCredential < ActiveRecord::Base
  attr_accessible :access_token, :shop_name, :store_id, :last_imported_at, :shopify_status, :shipped_status, :unshipped_status, :partial_status, :modified_barcode_handling, :generating_barcodes, :product_last_import, :import_inventory_qoh

  attr_writer :permission_url

  belongs_to :store

  def get_status
  	val = ""
    val = "shipped%2C" if self.shipped_status?
    val = val +"unshipped%2C" if self.unshipped_status?
    val = val + "partial%2C" if self.partial_status?
    val
  end
end
