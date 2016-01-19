class SyncOption < ActiveRecord::Base
  attr_accessible :bc_product_id, :product_id, :bc_product_sku, :sync_with_bc, :mg_rest_product_id, :sync_with_mg_rest
  belongs_to :product

  def self.create_update_sync_option(params)
    product = Product.find_by_id(params[:id])
    sync_option = product.sync_option || product.build_sync_option
    sync_option.sync_with_bc = params["sync_with_bc"]
    sync_option.bc_product_id = params["bc_product_id"].to_i!=0 ? params["bc_product_id"] : nil
    sync_option.bc_product_sku = params["bc_product_sku"].try(:strip)
    sync_option.sync_with_mg_rest = params["sync_with_mg_rest"]
    sync_option.mg_rest_product_id = params["mg_rest_product_id"].to_i!=0 ? params["mg_rest_product_id"] : nil
    sync_option.save
  end
end
