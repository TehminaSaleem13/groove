class ProductKitSkus < ActiveRecord::Base
  belongs_to :product
  attr_accessible :sku
  has_many :order_item_kit_products, dependent: :destroy

  def add_product_in_order_items
  	@order_items = OrderItem.where(:product_id => self.product_id)
  	@order_items.each do |order_item|
  		order_item_kit_product = OrderItemKitProduct.new
  		order_item_kit_product.product_kit_skus = self
  		order_item_kit_product.order_item = order_item
  		order_item_kit_product.save
  	end
  end

  def remove_product_from_order_items
  	@order_items = OrderItem.where(:product_id => self.product_id)
  	@order_items.each do |order_item|
  		order_item_kit_product = OrderItemKitProduct.new
  		order_item_kit_product.product_kit_skus = self
  		order_item_kit_product.order_item = order_item
  		order_item_kit_product.save
  	end  	
  end

  def option_product
    Product.find(self.option_product_id)
  end
end
