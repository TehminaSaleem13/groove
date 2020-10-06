class ShippingEasyCredential < ActiveRecord::Base
  # attr_accessible :api_key, :api_secret, :gen_barcode_from_sku, :import_ready_for_shipment, :import_shipped, :last_imported_at, :ready_to_ship, :store_api_key, :import_upc, :allow_duplicate_id, :store_id, :popup_shipping_label
  before_save :check_if_null_or_undefined

  belongs_to :store

  private
  def check_if_null_or_undefined
  	self.api_key = nil if self.api_key=="null" or self.api_key=="undefined"
  	self.api_secret = nil if self.api_secret=="null" or self.api_secret=="undefined"
  end
end
