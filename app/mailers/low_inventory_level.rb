class LowInventoryLevel < ActionMailer::Base
  default from: "app@groovepacker.com"

  def notify(general_settings, tenant)
    begin
      Apartment::Tenant.switch(tenant)
      general_setting = GeneralSetting.all.first
      @products_list = get_entire_list(tenant)
      @products_list.each_slice(4000).with_index  do |products_list, page_no|
        LowInventoryLevel.send_mail(products_list, page_no, tenant, general_setting).deliver
      end 
      #import_orders_obj = ImportOrders.new
      #import_orders_obj.reschedule_job('low_inventory_email', tenant)
    rescue Exception => ex
      LowInventoryLevel.error_on_low_inv_email(ex, tenant).deliver
    end
  end

  def send_mail(products_list, page_no, tenant, general_setting)
    page_info = "Page #{page_no + 1}" unless  page_no == 0 && products_list.count < 4000 
    @products_list = products_list
    @general_setting = general_setting
    mail to: general_setting.low_inventory_email_address,
           subject: "GroovePacker #{tenant} Low Inventory Alert #{page_info}"
  end

  def error_on_low_inv_email(ex, tenant)
    Apartment::Tenant.switch(tenant)
    @tenant = tenant
    @exception = ex
    mail to: ENV["FAILED_IMPORT_NOTIFICATION_EMAILS"],
         subject: "[#{tenant}] [#{Rails.env}] Low Inventory Alert failed"
  end

  def build_single_hash(product)

  end

  def get_entire_list(tenant)
    low_limit = ActiveRecord::Base::sanitize(GeneralSetting.all.first.default_low_inventory_alert_limit)
    # warehouses = ProductInventoryWarehouses.find_by_sql('SELECT * FROM '+tenant+'.product_inventory_warehouses WHERE (product_inv_alert = 0 AND available_inv <='+low_limit.to_s+') OR (product_inv_alert = 1 AND available_inv <= product_inv_alert_level AND product_inv_alert_level != 0)')
    # product_ids = []
    # warehouses.each do |warehouse|
    #   product_ids.push(warehouse.product_id)
    # end
    # products = Product.find_all_by_id(product_ids)
    products =
      Product.where('status != ?', "inactive")
      .joins(:product_inventory_warehousess)
      .includes(
        :product_skus,
        :product_images,
        :product_barcodes,
        product_inventory_warehousess: :inventory_warehouse
      )
      .where(
        "product_inv_alert = 0 AND available_inv <= #{low_limit}"\
        " OR product_inv_alert = 1 AND available_inv <= product_inv_alert_level"\
        " AND product_inv_alert_level != 0"
      )
    
    return products.to_a.uniq
  end
end
