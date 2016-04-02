class ProductInventoryWarehouses < ActiveRecord::Base
  belongs_to :product
  attr_accessible :qty, :alert, :location_primary, :location_secondary, :available_inv, :allocated_inv, :inventory_warehouse_id

  belongs_to :inventory_warehouse

  def quantity_on_hand
    self.available_inv + self.allocated_inv
  end

  def quantity_on_hand=(value)
    self.available_inv = value.to_i - self.allocated_inv
  end

  def self.copy_inventory_data_for_aliasing(product_alias, product_orig)
    orig_product_inv_wh = product_orig.primary_warehouse
    aliased_inventory = product_alias.primary_warehouse
    

    if orig_product_inv_wh.blank?
      orig_product_inv_wh = self.create_inv_warehouse_if_nil(orig_product_inv_wh, aliased_inventory)
    end

    if orig_product_inv_wh.product.is_kit == 0
      orig_product_inv_wh = self.update_inv_warehouse_for_kit_product(orig_product_inv_wh, aliased_inventory)
    else
      orig_product_inv_wh = self.update_inv_warehouse_for_product(orig_product_inv_wh, aliased_inventory)
    end

    aliased_inventory.reload
  end

  def self.create_inv_warehouse_if_nil(orig_product_inv_wh, aliased_inventory)
    orig_product_inv_wh = ProductInventoryWarehouses.new
    orig_product_inv_wh.inventory_warehouse_id = aliased_inventory.inventory_warehouse_id
    orig_product_inv_wh.product_id = product_orig.id
    orig_product_inv_wh.quantity_on_hand = aliased_inventory.quantity_on_hand
    orig_product_inv_wh.save
    orig_product_inv_wh
  end

  def self.update_inv_warehouse_for_kit_product(orig_product_inv_wh, aliased_inventory)
    #copy over the qoh of original as QOH of original should not change in aliasing
    orig_product_qoh = orig_product_inv_wh.quantity_on_hand
    orig_product_inv_wh.allocated_inv = orig_product_inv_wh.allocated_inv + aliased_inventory.allocated_inv

    orig_product_inv_wh.sold_inv = orig_product_inv_wh.sold_inv + aliased_inventory.sold_inv
    orig_product_inv_wh.quantity_on_hand = orig_product_qoh
    orig_product_inv_wh.save
    orig_product_inv_wh
  end

  def self.update_inv_warehouse_for_product(orig_product_inv_wh, aliased_inventory)
    orig_product_inv_wh.product.product_kit_skuss.each do |kit_sku|
  	  kit_option_product_wh = kit_sku.option_product.primary_warehouse
  	  return if kit_option_product_wh.nil?
      orig_kit_product_qoh = kit_option_product_wh.quantity_on_hand
      kit_option_product_wh.allocated_inv = kit_option_product_wh.allocated_inv + (kit_sku.qty * aliased_inventory.allocated_inv)

      kit_option_product_wh.sold_inv = kit_option_product_wh.sold_inv + (kit_sku.qty * aliased_inventory.sold_inv)
      kit_option_product_wh.quantity_on_hand = orig_kit_product_qoh
      kit_option_product_wh.save
    end
  end

end
