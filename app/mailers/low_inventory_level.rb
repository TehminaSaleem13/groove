class LowInventoryLevel < ActionMailer::Base
  default from: "app@groovepacker.com"

  def notify(general_settings, tenant)
    begin
      Apartment::Tenant.switch!(tenant)
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
    generate_low_inv_export_data
    if @products.present?
      @filename = "groovepacker-#{tenant}_low_inventory_alert-#{Time.current}.csv"
      generate_low_inv_export_csv
      attachments[@filename] = File.read("public/#{@filename}")
    end
    mail to: general_setting.low_inventory_email_address,
           subject: "GroovePacker #{tenant} Low Inventory Alert #{page_info}"
  end

  def generate_low_inv_export_data
    @products = []
    @general_setting = GeneralSetting.all.first
    @products_list.each do |product|
      product_hash = Hash.new
      product_hash['id'] = product.id
      product_hash['name'] = product.name
      if product.product_skus.length > 0
        product_hash['sku'] = product.product_skus.first.sku
      else
        product_hash['sku'] = '-'
      end
      if product.product_images.length > 0
        product_hash['image'] = product.product_images.first.image
      else
        product_hash['image'] = '-'
      end
      product_hash['warehouses'] = []
      low_inv_found = false
      product.product_inventory_warehousess.each do |wh|
        wh_hash = Hash.new

        if !wh.inventory_warehouse.nil?
          wh_hash['name'] = wh.inventory_warehouse.name
        else
          wh_hash['name'] = 'Not Available'
        end
        wh_hash['available_inv'] = wh.available_inv

        if !wh.location_primary.nil?
          wh_hash['primary_location'] = wh.location_primary
        else
          wh_hash['primary_location'] = 'Not Available'
        end

        if !wh.location_secondary.nil?
          wh_hash['secondary_location'] = wh.location_secondary
        else
          wh_hash['secondary_location'] = 'Not Available'
        end

        if !wh.location_tertiary.nil?
          wh_hash['tertiary_location'] = wh.location_tertiary
        else
          wh_hash['tertiary_location'] = 'Not Available'
        end

        if !wh.location_primary_qty.nil?
          wh_hash['primary_location_qty'] = wh.location_primary_qty
        else
          wh_hash['primary_location_qty'] = 'Not Available'
        end

        if !wh.location_secondary_qty.nil?
          wh_hash['secondary_location_qty'] = wh.location_secondary_qty
        else
          wh_hash['secondary_location_qty'] = 'Not Available'
        end

        if !wh.location_tertiary_qty.nil?
          wh_hash['tertiary_location_qty'] = wh.location_tertiary_qty
        else
          wh_hash['tertiary_location_qty'] = 'Not Available'
        end

        if (wh.product_inv_alert && wh.product_inv_alert_level > 0)
          wh_hash['threshold'] = wh.product_inv_alert_level
        else
          wh_hash['threshold'] = @general_setting.default_low_inventory_alert_limit
        end

        if ((wh.available_inv <= @general_setting.default_low_inventory_alert_limit) && !wh.product_inv_alert) ||
          (wh.product_inv_alert && wh.product_inv_alert_level > 0 && wh.available_inv <= wh.product_inv_alert_level)
          wh_hash['style'] = 'color:#D21C1C;'
          low_inv_found = true
        else
          wh_hash['style'] = 'color:black;'
        end
        product_hash['warehouses'].push(wh_hash)
      end
      unless product_hash['warehouses'].length <= 1
        product_hash['warehouses'] = product_hash['warehouses'].sort_by { |hash| hash['threshold'] }.reverse!
      end
      @products.push(product_hash) if low_inv_found
    end
  end

  def generate_low_inv_export_csv
    headers = ['Image', 'SKU', 'Product Name', 'Warehouse Name', 'Available/Threshold', 'Primary Location', 'Primary Location Qty', 'Secondary Location', 'Secondary Location Qty', 'Tertiary Location', 'Tertiary Location Qty']

    data = CSV.generate(headers: true) do |csv|
      csv << headers#.join(', ') + "\n"
      @products.each do |product|
        product['warehouses'].each  do |wh|
          csv << [product['image'], product['sku'], product['name'], wh['name'], "#{wh['available_inv']}/#{wh['threshold']}", wh['primary_location'], wh['primary_location_qty'], wh['secondary_location'], wh['secondary_location_qty'], wh['tertiary_location'], wh['tertiary_location_qty']]#.join(', ') + "\n"
        end
      end
    end
    File.open("public/#{@filename}", 'w+', {force_quotes: true} ) { |f| f.write data }
  end

  def error_on_low_inv_email(ex, tenant)
    Apartment::Tenant.switch!(tenant)
    @tenant = tenant
    @exception = ex
    mail to: ENV["FAILED_IMPORT_NOTIFICATION_EMAILS"],
         subject: "[#{tenant}] [#{Rails.env}] Low Inventory Alert failed"
  end

  def build_single_hash(product)

  end

  def get_entire_list(tenant)
    low_limit = ActiveRecord::Base.connection.quote(GeneralSetting.all.first.default_low_inventory_alert_limit)
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
