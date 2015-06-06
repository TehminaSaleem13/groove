module Groovepacker
  module Products
    class BulkActions
      include ProductsHelper

      def status_update(tenant,params,bulk_actions_id)
        Apartment::Tenant.switch(tenant)
        result = Hash.new
        result['messages'] =[]
        result['status'] = true
        bulk_action = GrooveBulkActions.find(bulk_actions_id)
        begin
          products = list_selected_products(params)
          unless products.nil?
            bulk_action.total = products.length
            bulk_action.completed = 0
            bulk_action.status = 'in_progress'
            bulk_action.save
            products.each do|single_product|
              product = Product.find(single_product['id'])
              bulk_action.reload
              if bulk_action.cancel?
                bulk_action.status = 'cancelled'
                bulk_action.save
                return true
              end
              bulk_action.current = product.name
              bulk_action.save
              current_status = product.status
              product.status = params[:status]
              if product.save
                product.reload
                if product.status !='inactive'
                  if !product.update_product_status && params[:status] == 'active'
                    result['status'] &= false
                    if product.is_kit == 1
                      result['messages'].push('There was a problem changing kit status for '+
                                                   product.name + '. Reason: In order for a Kit to be Active it needs to '+
                                                   'have at least one item and every item in the Kit must be Active.')
                    else
                      result['messages'].push('There was a problem changing product status for '+
                                                   product.name + '. Reason: In order for a product to be Active it needs to '+
                                                   'have at least one SKU and one barcode.')
                    end
                    product.status = current_status
                    product.save
                  end
                else
                  product.update_due_to_inactive_product
                end
              else
                result['status'] &= false
                result['messages'].push('There was a problem changing products status for '+product.name)
              end
              bulk_action.completed = bulk_action.completed + 1
              bulk_action.save
            end
          end
          unless bulk_action.cancel?
            bulk_action.status = result['status'] ? 'completed' : 'failed'
            bulk_action.messages = result['messages']
            bulk_action.current = ''
            bulk_action.save
          end
        rescue Exception => e
          bulk_action.status = 'failed'
          bulk_action.messages = ['Some error occurred']
          bulk_action.current = ''
          bulk_action.save
        end
      end

      def delete(tenant,params,bulk_actions_id)
        Apartment::Tenant.switch(tenant)
        result = Hash.new
        result['messages'] =[]
        result['status'] = true
        bulk_action = GrooveBulkActions.find(bulk_actions_id)

        begin
          products = list_selected_products(params)
          bulk_action.total = products.length
          bulk_action.completed = 0
          bulk_action.status = 'in_progress'
          bulk_action.save
          unless products.nil?
            products.each do|single_product|
              product = Product.find(single_product['id'])
              bulk_action.reload
              if bulk_action.cancel?
                bulk_action.status = 'cancelled'
                bulk_action.save
                return true
              end
              bulk_action.current = product.name
              bulk_action.save
              product.order_items.each do |order_item|
                unless order_item.order.nil?
                  order_item.order.status = 'onhold'
                  order_item.order.save
                  order_item.order.addactivity("An item with Name #{product.name} and " +
                                                   "SKU #{product.primary_sku} has been deleted",
                                               current_user.username,
                                               'deleted_item'
                  )
                end
                order_item.destroy
              end

              ProductKitSkus.where(option_product_id: product.id).each do |product_kit_sku|
                product_kit_sku.product.status = 'new'
                product_kit_sku.product.save
                product_kit_sku.product.product_kit_activities.create(
                    activity_message: "An item with Name #{product.name} and " +
                        "SKU #{product.primary_sku} has been deleted",
                    username: current_user.username,
                    activity_type: 'deleted_item'
                )
                product_kit_sku.destroy
              end

              if product.destroy
                result['status'] &= true
              else
                result['status'] &= false
                result['messages'] = product.errors.full_messages
              end
              bulk_action.completed = bulk_action.completed + 1
              bulk_action.save
            end
          end
          unless bulk_action.cancel?
            bulk_action.status = result['status'] ? 'completed' : 'failed'
            bulk_action.messages = result['messages']
            bulk_action.current = ''
            bulk_action.save
          end
        rescue Exception => e
          bulk_action.status = 'failed'
          bulk_action.messages = ['Some error occurred']
          bulk_action.current = ''
          bulk_action.save
        end
      end

      def duplicate(tenant,params,bulk_actions_id)
        Apartment::Tenant.switch(tenant)
        result = Hash.new
        result['messages'] =[]
        result['status'] = true
        bulk_action = GrooveBulkActions.find(bulk_actions_id)

        begin
          products = list_selected_products(params)
          bulk_action.total = products.length
          bulk_action.completed = 0
          bulk_action.status = 'in_progress'
          bulk_action.save
          unless products.nil?
            products.each do|single_product|
              #copy product
              product = Product.find(single_product['id'])
              bulk_action.reload

              if bulk_action.cancel?
                bulk_action.status = 'cancelled'
                bulk_action.save
                return true
              end
              bulk_action.current = product.name
              bulk_action.save

              newproduct = product.dup
              index = 0
              newproduct.name = product.name+" "+index.to_s
              productslist = Product.where(:name=>newproduct.name)
              begin
                index = index + 1
                #todo: duplicate sku, images, categories associated with product too.
                newproduct.name = product.name+" "+index.to_s
                productslist = Product.where(:name=>newproduct.name)
              end while(!productslist.nil? && productslist.length > 0)

              #copy barcodes
              product.product_barcodes.each do |barcode|
                index = 0
                newbarcode = barcode.barcode+" "+index.to_s
                barcodeslist = ProductBarcode.where(:barcode=>newbarcode)
                begin
                  index = index + 1
                  #todo: duplicate sku, images, categories associated with product too.
                  newbarcode = barcode.barcode+" "+index.to_s
                  barcodeslist = ProductBarcode.where(:barcode=>newbarcode)
                end while(!barcodeslist.nil? && barcodeslist.length > 0)

                newbarcode_item = ProductBarcode.new
                newbarcode_item.barcode = newbarcode
                newproduct.product_barcodes << newbarcode_item
              end

              #copy skus
              product.product_skus.each do |sku|
                index = 0
                newsku = sku.sku+" "+index.to_s
                skuslist = ProductSku.where(:sku=>newsku)
                begin
                  index = index + 1
                  #todo: duplicate sku, images, categories associated with product too.
                  newsku = sku.sku+" "+index.to_s
                  skuslist = ProductSku.where(:sku=>newsku)
                end while(!skuslist.nil? && skuslist.length > 0)

                newsku_item = ProductSku.new
                newsku_item.sku = newsku
                newsku_item.purpose = sku.purpose
                newproduct.product_skus << newsku_item
              end

              #copy images
              product.product_images.each do |image|
                newimage = ProductImage.new
                newimage = image.dup
                newproduct.product_images << newimage
              end

              #copy categories
              product.product_cats.each do |category|
                newcategory = ProductCat.new
                newcategory = category.dup
                newproduct.product_cats << newcategory
              end

              #copy product kit items
              product.product_kit_skuss.each do |sku|
                new_kit_sku = ProductKitSkus.new
                new_kit_sku = sku.dup
                newproduct.product_kit_skuss << new_kit_sku
              end

              #copy product inventory warehouses
              product.product_inventory_warehousess.each do |warehouse|
                new_warehouse = ProductInventoryWarehouses.new
                new_warehouse = warehouse.dup
                newproduct.product_inventory_warehousess << new_warehouse
              end


              if !newproduct.save(:validate => false)
                result['status'] = false
                result['messages'] = newproduct.errors.full_messages
              end
              bulk_action.completed = bulk_action.completed + 1
              bulk_action.save
            end
          end
          unless bulk_action.cancel?
            bulk_action.status = result['status'] ? 'completed' : 'failed'
            bulk_action.messages = result['messages']
            bulk_action.current = ''
            bulk_action.save
          end
        rescue Exception => e
          bulk_action.status = 'failed'
          bulk_action.messages = ['Some error occurred']
          bulk_action.current = ''
          bulk_action.save
        end
      end
    end
  end
end

