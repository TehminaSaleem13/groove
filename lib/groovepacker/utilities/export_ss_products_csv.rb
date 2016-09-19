class ExportSsProductsCsv
  
  def export_active_products(tenant_name)
  	Apartment::Tenant.switch(tenant_name)
    require 'csv'
    result = Hash.new
    result['status'] = true
    result['messages'] = []
    products = Product.where(status: 'active')
    unless products.empty?
      filename = 'groove-products-'+Time.now.to_s+'.csv'
      row_map = {
        :SKU => '',
        :Name => '',
        :WarehouseLocation => '',
        :WeightOz => '',
        :Category => '',
        :Tag1 => '',
        :Tag2 => '',
        :Tag3 => '',
        :Tag4 => '',
        :Tag5 => '',
        :CustomsDescription => '',
        :CustomsValue => '',
        :CustomsTariffNo => '',
        :CustomsCountry => '',
        :ThumbnailUrl => '',
        :UPC => '',
        :FillSKU => '',
        :Length => '',
        :Width => '',
        :Height => '',
        :UseProductName => '',
        :Active => ''
      }
      data = CSV.generate do |csv|
        csv << row_map.keys

        products.each do |product|
          single_row = row_map.dup
          single_row[:SKU] = product.primary_sku
          single_row[:Name] = product.name
          single_row[:WarehouseLocation] = product.primary_warehouse.location_primary
          unless product.weight.round == 0
            single_row[:WeightOz] = product.weight.round.to_s
          else
            single_row[:WeightOz] = ''
          end
          single_row[:Category] = product.primary_category
          single_row[:Tag1] = ''
          single_row[:Tag2] = ''
          single_row[:Tag3] = ''
          single_row[:Tag4] = ''
          single_row[:Tag5] = ''
          single_row[:CustomsDescription] = ''
          single_row[:CustomsValue] = ''
          single_row[:CustomsTariffNo] = ''
          single_row[:CustomsCountry] = product.order_items.first.order.country unless product.order_items.empty? || product.order_items.first.order.nil?
          single_row[:ThumbnailUrl] = ''
          single_row[:UPC] = product.primary_barcode
          single_row[:FillSKU] = ''
          single_row[:Length] = ''
          single_row[:Width] = ''
          single_row[:Height] = ''
          single_row[:UseProductName] = ''
          single_row[:Active] = product.is_active

          csv << single_row.values
        end
      end
    else
      result['messages'] << 'There are no active products'
    end

    unless result['status']
      data = CSV.generate do |csv|
        csv << result['messages']
      end
      filename = 'error.csv'
    end
    no_product = products.blank?
    object_url = GroovS3.create_order_csv(Apartment::Tenant.current, 'product', filename, data).url rescue nil
    CsvExportMailer.send_s3_product_object_url(filename, object_url, Apartment::Tenant.current, no_product).deliver 
  end
end