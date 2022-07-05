namespace :system do
  desc "Set default scanpack setting attributes"
  task :update_order_item_names => :environment do

    tenants = Tenant.pluck(:name)
    unless tenants.empty?
      tenants.each do |tenant|
        begin
          Apartment::Tenant.switch! tenant
          OrderItem.includes(:product).where(name: '').find_each do |item|
            item.update_columns(name: item.product.name) if item.product
          end
        end
      end
    end
  end
end
