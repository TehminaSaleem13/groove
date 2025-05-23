# frozen_string_literal: true

class ProductInventoryWarehouses < ApplicationRecord
  @@set_order_id = nil
  belongs_to :product
  # attr_accessible :qty, :alert, :location_primary, :location_secondary, :location_tertiary, :location_quaternary, :location_primary_qty, :location_secondary_qty, :location_tertiary_qty, :location_quaternary_qty, :available_inv, :allocated_inv, :inventory_warehouse_id
  attr_accessor :order_id
  belongs_to :inventory_warehouse
  around_update :create_activity#, if: :is_create_activity?

  def quantity_on_hand
    available_inv + allocated_inv
  end

  def quantity_on_hand=(value)
    self.available_inv = value.to_i - allocated_inv
  end

  def self.copy_inventory_data_for_aliasing(product_alias, product_orig)
    orig_product_inv_wh = product_orig.primary_warehouse
    aliased_inventory = product_alias.primary_warehouse

    if orig_product_inv_wh.blank?
      orig_product_inv_wh = create_inv_warehouse_if_nil(orig_product_inv_wh, aliased_inventory)
    end

    orig_product_inv_wh = if orig_product_inv_wh.product.is_kit == 0
                            update_inv_warehouse_for_kit_product(orig_product_inv_wh, aliased_inventory)
                          else
                            update_inv_warehouse_for_product(orig_product_inv_wh, aliased_inventory)
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
    # copy over the qoh of original as QOH of original should not change in aliasing
    orig_product_qoh = orig_product_inv_wh.quantity_on_hand
    orig_product_inv_wh.allocated_inv = orig_product_inv_wh.allocated_inv + aliased_inventory.allocated_inv

    orig_product_inv_wh.sold_inv = orig_product_inv_wh.sold_inv + aliased_inventory.sold_inv
    orig_product_inv_wh.quantity_on_hand = orig_product_qoh + aliased_inventory&.quantity_on_hand.to_i
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
      kit_option_product_wh.quantity_on_hand = orig_kit_product_qoh + aliased_inventory&.quantity_on_hand.to_i
      kit_option_product_wh.save
    end
  end

  def self.adjust_available_inventory(params, result)
    product = Product.find_by_id(params[:id])
    if product.nil?
      result['status'] &= false
      result['error_messages'].push('Cannot find product with id: ' + params[:id])
      return result
    end

    product_inv_whs = ProductInventoryWarehouses.where(product_id: product.id, inventory_warehouse_id: params[:inv_wh_id]).last
    product_inv_whs ||= product.product_inventory_warehousess.build(inventory_warehouse_id: params[:inv_wh_id])

    result = update_inventory_data(product_inv_whs, params, result)
    result
  end

  def self.update_inventory_data(product_inv_whs, params, result)
    unless params[:inventory_count].blank?
      product_inv_whs, result = update_inventory_count(product_inv_whs, params, result)
    end

    %i[location_primary location_secondary location_tertiary].each do |loc|
      product_inv_whs[loc] = params[loc] unless params[loc].blank?
    end
    product_inv_whs.save
    result
  end

  def self.update_inventory_count(product_inv_whs, params, result)
    if params[:method] == 'recount'
      product_inv_whs.product.add_product_activity("The QOH of this item was changed from #{product_inv_whs.quantity_on_hand} to #{params[:inventory_count].to_i} ", params[:current_user]) if product_inv_whs.quantity_on_hand != params[:inventory_count].to_i
      product_inv_whs.quantity_on_hand = params[:inventory_count]
    elsif params[:method] == 'receive'
      product_inv_whs.product.add_product_activity("The QOH of this item was changed from #{product_inv_whs.quantity_on_hand} to #{product_inv_whs.quantity_on_hand + params[:inventory_count].to_i} ", params[:current_user])
      product_inv_whs.available_inv =
        product_inv_whs.available_inv + params[:inventory_count].to_i
    else
      result['status'] &= false
      result['error_messages'].push("Invalid method passed in parameter. Only 'receive' and 'recount' are valid. Passed in parameter: #{params[:method]}")
    end
    [product_inv_whs, result]
  end

  def update_allocated_inv
    self.available_inv = available_inv + allocated_inv
    self.allocated_inv = 0
    save!
  end


  def create_activity
    old_data = { 
      allocated_inv: allocated_inv_was, 
      available_inv: available_inv_was, 
    }
  
    yield
    
    new_data = { 
      allocated_inv: allocated_inv, 
      available_inv: available_inv, 
    }
  
    old_data.each do |key, old_value|
      new_value = new_data[key]    
      if self.order_id
        @@set_order_id  = self.order_id  
      end
      order_number = Order.find_by(id: @@set_order_id)&.increment_id || nil
      
      if old_value != new_value
        key_name = key == :allocated_inv ? "Allocated Inv" : "Available Inv"
        product.add_product_activity(
          "The #{key_name} has changed from #{old_value} to #{new_value}" + ( @@set_order_id ? " by scanning order #{order_number}" : "")
        )
      end
    end
  end
  
  
  

  private

  def is_create_activity?
    saved_change_to_available_inv || saved_change_to_allocated_inv 
  end

end
