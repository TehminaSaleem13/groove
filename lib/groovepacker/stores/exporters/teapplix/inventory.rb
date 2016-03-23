module Groovepacker
  module Stores
    module Exporters
      module Teapplix
        class Inventory < Groovepacker::Stores::Importers::Importer
          include ProductsHelper

          def push_inventories
            @credential = handler[:credential]
            @client = handler[:store_handle]
            current_tenant = handler[:current_tenant]
            Apartment::Tenant.switch(current_tenant)

            products = Product.joins(:sync_option).where("sync_with_teapplix=true and (teapplix_product_sku IS NOT NULL)")
            header = "\"Post Date\",\"Post Type\",\"Post Comment\",SKU,Quantity,Total,Location\n"
            inv_export_data = header + ""
            
            (products||[]).each do |product|
              inv_wh = product.product_inventory_warehousess.last
              sync_optn = product.sync_option
              if sync_optn.teapplix_product_sku && inv_wh.present?
                inv_level = (inv_wh.available_inv || 0) rescue 0
                inv_lavel = (inv_level < 0) ? 0 : inv_level
                inv_export_data = inv_export_data + "\"#{Date.today.strftime("%m/%d/%Y")}\",\"in-stock\",\"\",\"#{sync_optn.teapplix_product_sku}\",\"#{inv_lavel}\",\"\",\"\"" 
              end
            end
            upload_folder = "teapplix_csv_uploads/csv/#{current_tenant}/#{@credential.store_id}"
            GroovS3.create_teapplix_csv(upload_folder, "upload", inv_export_data)
            resp = GroovS3.find_teapplix_csv(upload_folder, "upload")
            csv_url = resp.url rescue nil
            return if csv_url.blank?
            
            update_inv_on_teapplix_for_sync_option(csv_url)
          end

          private
            def update_inv_on_teapplix_for_sync_option(csv_url)
              response = @client.update_inventory_qty_on_teapplix(csv_url)
            end
        end
      end
    end
  end
end
