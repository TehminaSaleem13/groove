# frozen_string_literal: true

class LowInventoryLevel < ActionMailer::Base
  default from: 'app@groovepacker.com'

  def notify(_general_settings, tenant)
    Apartment::Tenant.switch!(tenant)
    general_setting = GeneralSetting.all.first
    @products_list = get_entire_list(tenant)
    @products_list.each_slice(4000).with_index do |products_list, page_no|
      LowInventoryLevel.send_mail(products_list, page_no, tenant, general_setting).deliver
    end
    # import_orders_obj = ImportOrders.new
    # import_orders_obj.reschedule_job('low_inventory_email', tenant)
  rescue Exception => e
    LowInventoryLevel.error_on_low_inv_email(e, tenant).deliver
  end

  def send_mail(products_list, page_no, tenant, general_setting)
    page_info = "Page #{page_no + 1}" unless page_no == 0 && products_list.count < 4000
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
    joined_orders = Order.includes(order_items: [{ order_item_kit_products: [:product_kit_skus] }, :product])
    @products_list.each do |product|
      product_hash = {}
      pro_orders = joined_orders.where(order_items: { product: product }).or(joined_orders.where(order_items: { order_item_kit_products: { product_kit_skus: { option_product_id: product.id } } })).distinct
      product_hash['id'] = product.id
      product_hash['name'] = product.name
      product_hash['sku'] = if !product.product_skus.empty?
                              product.product_skus.first.sku
                            else
                              '-'
                            end
      product_hash['image'] = if !product.product_images.empty?
                                product.product_images.first.image
                              else
                                '-'
                              end
      product_hash['store_name'] = product.get_store_name(pro_orders) 
      product_hash['warehouses'] = []
      low_inv_found = false
      product.product_inventory_warehousess.each do |wh|
        wh_hash = {}

        wh_hash['name'] = if !wh.inventory_warehouse.nil?
                            wh.inventory_warehouse.name
                          else
                            'Not Available'
                          end
        wh_hash['available_inv'] = wh.available_inv

        wh_hash['primary_location'] = if !wh.location_primary.nil?
                                        wh.location_primary
                                      else
                                        'Not Available'
                                      end

        wh_hash['secondary_location'] = if !wh.location_secondary.nil?
                                          wh.location_secondary
                                        else
                                          'Not Available'
                                        end

        wh_hash['tertiary_location'] = if !wh.location_tertiary.nil?
                                         wh.location_tertiary
                                       else
                                         'Not Available'
                                       end

        wh_hash['primary_location_qty'] = if !wh.location_primary_qty.nil?
                                            wh.location_primary_qty
                                          else
                                            'Not Available'
                                          end

        wh_hash['secondary_location_qty'] = if !wh.location_secondary_qty.nil?
                                              wh.location_secondary_qty
                                            else
                                              'Not Available'
                                            end

        wh_hash['tertiary_location_qty'] = if !wh.location_tertiary_qty.nil?
                                             wh.location_tertiary_qty
                                           else
                                             'Not Available'
                                           end

        wh_hash['threshold'] = if wh.product_inv_alert && wh.product_inv_alert_level > 0
                                 wh.product_inv_alert_level
                               else
                                 @general_setting.default_low_inventory_alert_limit
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
    headers = ['Image', 'SKU', 'Product Name', 'Store Name', 'Warehouse Name', 'Available/Threshold', 'Primary Location', 'Primary Location Qty', 'Secondary Location', 'Secondary Location Qty', 'Tertiary Location', 'Tertiary Location Qty']

    data = CSV.generate(headers: true) do |csv|
      csv << headers # .join(', ') + "\n"
      @products.each do |product|
        product['warehouses'].each  do |wh|
          csv << [product['image'], product['sku'], product['name'], product['store_name'], wh['name'], "#{wh['available_inv']}/#{wh['threshold']}", wh['primary_location'], wh['primary_location_qty'], wh['secondary_location'], wh['secondary_location_qty'], wh['tertiary_location'], wh['tertiary_location_qty']] # .join(', ') + "\n"
        end
      end
    end
    File.open("public/#{@filename}", 'w+', force_quotes: true) { |f| f.write data }
  end

  def error_on_low_inv_email(ex, tenant)
    Apartment::Tenant.switch!(tenant)
    @tenant = tenant
    @exception = ex
    mail to: ENV['FAILED_IMPORT_NOTIFICATION_EMAILS'],
         subject: "[#{tenant}] [#{Rails.env}] Low Inventory Alert failed"
  end

  def build_single_hash(product); end

  def get_entire_list(_tenant)
    low_limit = ActiveRecord::Base.connection.quote(GeneralSetting.all.first.default_low_inventory_alert_limit)
    # warehouses = ProductInventoryWarehouses.find_by_sql('SELECT * FROM '+tenant+'.product_inventory_warehouses WHERE (product_inv_alert = 0 AND available_inv <='+low_limit.to_s+') OR (product_inv_alert = 1 AND available_inv <= product_inv_alert_level AND product_inv_alert_level != 0)')
    # product_ids = []
    # warehouses.each do |warehouse|
    #   product_ids.push(warehouse.product_id)
    # end
    # products = Product.find_all_by_id(product_ids)
    products =
      Product.where('status != ?', 'inactive')
             .joins(:product_inventory_warehousess)
             .includes(
               :product_skus,
               :product_images,
               :product_barcodes,
               product_inventory_warehousess: :inventory_warehouse
             )
             .where(
               "product_inv_alert = 0 AND available_inv <= #{low_limit}"\
               ' OR product_inv_alert = 1 AND available_inv <= product_inv_alert_level'\
               ' AND product_inv_alert_level != 0'
             )

    products.to_a.uniq
  end
end
