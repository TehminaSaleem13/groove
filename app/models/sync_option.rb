class SyncOption < ActiveRecord::Base
  attr_accessible :bc_product_id, :product_id, :sync_with_bc
  belongs_to :product
end
