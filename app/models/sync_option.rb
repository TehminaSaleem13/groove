class SyncOption < ActiveRecord::Base
  attr_accessible :bc_product_id, :product_id, :bc_product_sku, :sync_with_bc, :mg_rest_product_id, :sync_with_mg_rest,
                  :sync_with_shopify, :shopify_product_variant_id
  belongs_to :product
end
