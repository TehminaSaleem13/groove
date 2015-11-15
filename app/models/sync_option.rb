class SyncOption < ActiveRecord::Base
  attr_accessible :bc_product_id, :product_id, :bc_product_sku, :sync_with_bc
  belongs_to :product
end
