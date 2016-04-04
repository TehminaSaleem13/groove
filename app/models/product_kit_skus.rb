class ProductKitSkus < ActiveRecord::Base
  belongs_to :product
  attr_accessible :sku
  has_many :order_item_kit_products, dependent: :destroy
  after_save :add_product_in_order_items
  after_save :update_inventory_levels
  #after_destroy :remove_product_from_order_items

  def add_product_in_order_items
    @order_items = OrderItem.where(:product_id => self.product_id)
    @order_items.each do |order_item|
      if OrderItemKitProduct.where(:order_item_id => order_item.id).where(:product_kit_skus_id => self.id).length == 0
        order_item_kit_product = OrderItemKitProduct.new
        order_item_kit_product.product_kit_skus = self
        order_item_kit_product.order_item = order_item
        order_item_kit_product.save
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
      params[:kit_products].each {|kit_product| result = self.remove_single_kit_product(kit, kit_product, params, result) }
    end
    kit.update_product_status
    return result
  end

  def self.remove_single_kit_product(kit, kit_product, params, result)
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
      kit.product_kit_skuss << @productkitsku
      return result if kit.save
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
