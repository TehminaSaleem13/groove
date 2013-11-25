class Product < ActiveRecord::Base
  belongs_to :store
  attr_accessible :name, :product_type, :store_product_id,
				    :status,
					:spl_instructions_4_packer,
					:spl_instructions_4_confirmation,
					:alternate_location,
					:barcode,
					:is_skippable,
					:packing_placement,
					:pack_time_adj,
					:is_kit,
					:kit_skus,
					:kit_parsing,
					:location_primary,
					:inv_wh1_qty,
					:inv_alert_wh1,
					:inv_wh2_qty,
					:inv_alert_wh2,
					:inv_wh3_qty,
					:inv_alert_wh3,
					:inv_wh4_qty,
					:inv_alert_wh4,
					:inv_wh5_qty,
					:inv_alert_wh5,
					:inv_wh6_qty,
					:inv_alert_wh6,
					:inv_wh7_qty,
					:inv_alert_wh7,
					:disable_conf_req

  has_many :product_skus
  has_many :product_cats
  has_many :product_barcodes
  has_many :product_images
  has_many :product_kit_skus
  has_many :product_inventory_warehousess
end
