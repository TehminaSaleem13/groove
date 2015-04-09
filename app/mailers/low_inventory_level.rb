class LowInventoryLevel < ActionMailer::Base
  default from: "app@groovepacker.com"
  
  def notify(general_settings, tenant)
    Apartment::Tenant.switch(tenant)
    @products_list = get_entire_list
  	mail to: general_settings.low_inventory_email_address, 
  		subject: "GroovePacker Low Inventory Alert"
    import_orders_obj = ImportOrders.new
    import_orders_obj.reschedule_job('low_inventory_email',tenant)
  end

  def build_single_hash(product)

  end

  def get_entire_list
    low_limit = ActiveRecord::Base::sanitize(GeneralSetting.all.first.default_low_inventory_alert_limit)
    warehouses = ProductInventoryWarehouses.find_by_sql('SELECT * FROM product_inventory_warehouses WHERE (product_inv_alert = 0 AND available_inv <='+low_limit.to_s+') OR (product_inv_alert = 1 AND available_inv <= product_inv_alert_level AND product_inv_alert_level != 0)')
    product_ids = []
    warehouses.each do |warehouse|
      product_ids.push(warehouse.product_id)
    end
    products = Product.find_all_by_id(product_ids)
    return products
  end
end
