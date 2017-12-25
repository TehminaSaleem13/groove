class ProductKitSkus < ActiveRecord::Base
  belongs_to :product
  attr_accessible :sku, :option_product_id, :qty
  has_many :order_item_kit_products, dependent: :destroy
  belongs_to :option_product, class_name: 'Product'
  after_save :add_product_in_order_items
  after_save :update_inventory_levels
  #after_destroy :remove_product_from_order_items

  cached_methods :option_product
  after_save :delete_cache

  def add_product_in_order_items
    tenant = Apartment::Tenant.current
    @order_items = OrderItem.where(:product_id => self.product_id)
    if @order_items.count > 50
      kit_sku = Groovepacker::Products::BulkActions.new
      kit_sku.delay.update_ordere_item_kit_product(tenant, self.product_id, self.id)
    else
      @order_items.each do |order_item| 
        if $redis.get("duplicate_item_check_2").blank?
          $redis.set("duplicate_item_check_2", true) 
          $redis.expire("duplicate_item_check_2", 54)
          if !OrderItemKitProduct.where(:order_item_id => order_item.id).map(&:product_kit_skus_id).include?(self.id)
            order_item_kit_product = OrderItemKitProduct.new
            order_item_kit_product.product_kit_skus = self
            order_item_kit_product.order_item = order_item
            order_item_kit_product.save
          end
        end
      end
    end
    true
  end

  def update_inventory_levels
    changed_hash = self.changes
    if changed_hash['qty'].nil?
      return true
    end
    initial_count = changed_hash['qty'][0]
    final_count = changed_hash['qty'][1]
    if initial_count.nil?
      initial_count = 0
    end
    if final_count.nil?
      final_count = 0
    end
    difference = final_count - initial_count

    Groovepacker::Inventory::Products.kit_item_inv_change(self, difference)

    true
  end

  def option_product
    Product.find(self.option_product_id)
  end

  def self.remove_products_from_kit(kit, params, result)
    if params[:kit_products].nil?
      result['messages'].push("No sku sent in the request")
      result['status'] &= false
    else
      params[:kit_products].reject! { |a| a=="" }
      tenant = Apartment::Tenant.current
      params[:kit_products].each do  |kit_product| 
        count = ProductKitSkus.find_by_option_product_id_and_product_id(kit_product, kit.id).order_item_kit_products.count rescue 0
        if count > 200
          result["success_messages"] = "Your request for 'remove item' has been queued"
          result["job"] = self.delay.remove_single_kit_product(kit, kit_product, params, result, tenant) 
        else
          result =self.remove_single_kit_product(kit, kit_product, params, result, tenant) 
        end
      end
    end
    kit.update_product_status
    return result
  end

  def self.remove_single_kit_product(kit, kit_product, params, result, tenant)
    Apartment::Tenant.switch tenant
    product_kit_sku = ProductKitSkus.find_by_option_product_id_and_product_id(kit_product, kit.id)
    if product_kit_sku.nil?
      result['messages'].push("Product #{kit_product} not found in item")
      result['status'] &= false
      return result
    end
    product_kit_sku.qty = 0
    product_kit_sku.save
    return result if product_kit_sku.destroy
    result['messages'].push("Product #{kit_product} could not be removed fronm kit")
    result['status'] &= false
    result
  end

  def self.app_product_to_kit(kit, params, result)
    if params[:product_ids].nil?
      result['messages'].push("No item sent in the request")
      result['status'] &= false
    else
      items = Product.find(params[:product_ids])
      items.each { |item| result = self.add_single_product_to_kit(kit, item, params, result) }
    end
    return result
  end

  def self.add_single_product_to_kit(kit, item, params, result)
    if item.nil?
      result['messages'].push("Item does not exist")
      result['status'] &= false
      return result
    end
    product_kit_sku = ProductKitSkus.find_by_option_product_id_and_product_id(item.id, kit.id)
    if product_kit_sku.nil?
      @productkitsku = ProductKitSkus.new
      @productkitsku.option_product_id = item.id
      @productkitsku.qty = 1
      kit.product_kit_skuss << @productkitsku unless kit.product_kit_skuss.map(&:option_product_id).include?(@productkitsku.option_product_id)
      if kit.save
        kit.update_product_status
        return result 
      end
      result['messages'].push("Could not save kit with sku: "+@product_skus.first.sku)
      result['status'] &= false
    else
      result['messages'].push("The product with id #{item.id} has already been added to the kit")
      result['status'] &= false
    end
    item.update_product_status
    return result
  end
end
