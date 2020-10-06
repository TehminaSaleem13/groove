namespace :doo do
  desc "delete duplicate order item kit product"
  task :remove_duplicate_order_item_kit_products , [:tenant] => :environment do |t, args|
    if Rails.env=="production"
      Apartment::Tenant.switch! args[:tenant]
      OrderItem.includes(:product).where("products.is_kit" => 1).all.each do |item|
        begin
          kit_items = item.order_item_kit_products
          kit_items = kit_items.group(:product_kit_skus_id) 
          item.order_item_kit_products = kit_items
          item.save
        rescue Exception => e      
        end 
      end    
    end
    exit(1)
  end
end
