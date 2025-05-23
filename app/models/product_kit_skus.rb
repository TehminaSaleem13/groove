# frozen_string_literal: true

class ProductKitSkus < ApplicationRecord
  belongs_to :product
  # attr_accessible :sku, :option_product_id, :qty
  has_many :order_item_kit_products, dependent: :destroy
  belongs_to :option_product, class_name: 'Product'
  after_save :add_product_in_order_items
  after_save :update_inventory_levels
  # after_destroy :remove_product_from_order_items
  around_update :create_kit_activity#, if: :is_create_activity?


  cached_methods :option_product
  after_save :delete_cache

  def add_product_in_order_items
    tenant = Apartment::Tenant.current
    @order_items = OrderItem.where(product_id: product_id, scanned_status: %w[notscanned unscanned])
    # if @order_items.count > 50
    #   kit_sku = Groovepacker::Products::BulkActions.new
    #   latest_job = Delayed::Job.where(queue: "order_item_kit_product").last
    #   run_at = latest_job ? latest_job.run_at + 3.seconds : 1.seconds.from_now
    #   kit_sku.delay(:run_at => run_at, :queue => "order_item_kit_product").update_ordere_item_kit_product(tenant, self.product_id, self.id)
    # else
    @order_items.each do |order_item|
      next if OrderItemKitProduct.where(order_item_id: order_item.id).map(&:product_kit_skus_id).include?(id)

      order_item_kit_product = OrderItemKitProduct.new
      order_item_kit_product.product_kit_skus = self
      order_item_kit_product.order_item = order_item
      order_item_kit_product.save
    end
    # end
    true
  end

  def create_kit_activity
    old_qty = self.attribute_in_database('qty')
    old_packing_order = self.attribute_in_database('packing_order')
  
    yield
  
    new_qty = self.qty
    new_packing_order = self.packing_order
  
    if old_qty != new_qty
      product.add_product_activity(
        "The Quantity of kit has changed from #{old_qty} to #{new_qty}"
      )
    end
  
    if old_packing_order != new_packing_order
      product.add_product_activity(
        "The Packing Order of kit has changed from #{old_packing_order} to #{new_packing_order}"
      )
    end
  end  
    

  def update_inventory_levels
    changed_hash = saved_changes
    return true if changed_hash['qty'].nil?

    initial_count = changed_hash['qty'][0]
    final_count = changed_hash['qty'][1]
    initial_count = 0 if initial_count.nil?
    final_count = 0 if final_count.nil?
    difference = final_count - initial_count

    Groovepacker::Inventory::Products.kit_item_inv_change(self, difference)

    true
  end

  def option_product
    Product.find(option_product_id)
  end

  def self.remove_products_from_kit(kit, params, result, current_user)
    if params[:kit_products].nil?
      result['messages'].push('No sku sent in the request')
      result['status'] &= false
    else
      params[:kit_products].reject! { |a| a == '' }
      tenant = Apartment::Tenant.current
      params[:kit_products].each do |kit_product|
        count = begin
                  ProductKitSkus.find_by_option_product_id_and_product_id(kit_product, kit.id).order_item_kit_products.count
                rescue StandardError
                  0
                end
        if count > 200
          result['success_messages'] = "Your request for 'remove item' has been queued"
          result['job'] = delay(priority: 95).remove_single_kit_product(kit.id, kit_product, params, result, tenant, current_user.id)
        else
          result = remove_single_kit_product(kit.id, kit_product, params, result, tenant, current_user.id)
        end
      end
    end
    kit.update_product_status
    result
  end

  def self.remove_single_kit_product(kit_id, kit_product, _params, result, tenant, current_user_id)
    Apartment::Tenant.switch! tenant
    kit = Product.find(kit_id)
    current_user = User.find(current_user_id)
    product_kit_sku = ProductKitSkus.find_by_option_product_id_and_product_id(kit_product, kit.id)
    if product_kit_sku.nil?
      result['messages'].push("Product #{kit_product} not found in item")
      result['status'] &= false
      return result
    end
    product_kit_sku.qty = 0
    product_kit_sku.save
    new_sku = Product.find(product_kit_sku.option_product_id)
    kit.add_product_activity("The product with SKU #{new_sku.product_skus.first.sku} was removed as an item from this kit", current_user.name)
    return result if product_kit_sku.destroy

    result['messages'].push("Product #{kit_product} could not be removed fronm kit")
    result['status'] &= false
    result
  end

  def self.app_product_to_kit(kit, params, result, current_user)
    if params[:product_ids].nil?
      result['messages'].push('No item sent in the request')
      result['status'] &= false
    else
      items = Product.find(params[:product_ids])
      items.each { |item| result = add_single_product_to_kit(kit, item, params, result, current_user) }
    end
    result
  end

  def self.add_single_product_to_kit(kit, item, _params, result, current_user)
    if item.nil?
      result['messages'].push('Item does not exist')
      result['status'] &= false
      return result
    end

    if item.is_kit == 1
      item.product_kit_skuss.each { |product| result = add_kit_product_to_kit(kit, product, result) }
      kit.add_product_activity("Products from KIT SKU #{item.product_skus.first.sku} was added to KIT SKU #{kit.product_skus.first.sku}", current_user.name)

      return result
    end

    product_kit_sku = ProductKitSkus.find_by_option_product_id_and_product_id(item.id, kit.id)
    if product_kit_sku.nil?
      @productkitsku = ProductKitSkus.new
      @productkitsku.option_product_id = item.id
      @productkitsku.qty = 1
      unless kit.product_kit_skuss.map(&:option_product_id).include?(@productkitsku.option_product_id)
        new_sku = Product.find(@productkitsku.option_product_id)
        kit.add_product_activity("The product with SKU #{new_sku.product_skus.first.sku} was added as an item to this kit", current_user.name)
      end

      kit.product_kit_skuss << @productkitsku unless kit.product_kit_skuss.map(&:option_product_id).include?(@productkitsku.option_product_id)
      if kit.save
        kit.update_product_status
        return result
      end
      result['messages'].push('Could not save kit with sku: ' + @product_skus.first.sku)
      result['status'] &= false
    else
      result['messages'].push("The product with id #{item.id} has already been added to the kit")
      result['status'] &= false
    end
    item.update_product_status
    result
  end

  def self.add_kit_product_to_kit(kit, item, result)
    product_kit_sku = ProductKitSkus.find_by_option_product_id_and_product_id(item.option_product_id, kit.id)
    if product_kit_sku.nil?
      @productkitsku = ProductKitSkus.new
      @productkitsku.option_product_id = item.option_product_id
      @productkitsku.qty += item.qty

      kit.product_kit_skuss << @productkitsku unless kit.product_kit_skuss.map(&:option_product_id).include?(@productkitsku.option_product_id)
      return result if kit.save

      result['messages'].push('Could not save kit with sku: ' + kit.product_sku.first.sku)
      result['status'] &= false
    else
      product_kit_sku.qty += item.qty
      product_kit_sku.save
    end

    result
  end
end
