# frozen_string_literal: true

module Groovepacker
  module Products
    class BulkActions
      include ProductsHelper
      include SettingsHelper

      def update_ordere_item_kit_product(tenant, product_id, product_kit_sku_id)
        Apartment::Tenant.switch! tenant
        order_items = OrderItem.where(product_id:)
        order_items.each do |order_item|
          order_item_kit_product = OrderItemKitProduct.where(order_item_id: order_item.id).map(&:product_kit_skus_id)
          is_kit_sku_notexist = order_item_kit_product.include?(product_kit_sku_id.to_i)
          next if is_kit_sku_notexist

          # if !OrderItemKitProduct.where("order_item_id  = ? and product_kit_skus_id = ?", order_item.id, product_kit_skus_id)
          order_item_kit_product = OrderItemKitProduct.new
          order_item_kit_product.product_kit_skus = ProductKitSkus.find(product_kit_sku_id)
          order_item_kit_product.order_item = order_item
          unless OrderItemKitProduct.where(order_item_id: order_item.id).map(&:product_kit_skus_id).include?(product_kit_sku_id.to_i)
            order_item_kit_product.save
          end
        end
      end

      def status_update(tenant, params, bulk_actions_id, _username)
        Apartment::Tenant.switch!(tenant)
        result = {}
        result['messages'] = []
        result['status'] = true
        bulk_action = GrooveBulkActions.find(bulk_actions_id)
        begin
          products =
            list_selected_products(params)
            .includes(
              :product_kit_skuss, :product_barcodes,
              :product_skus, :product_kit_activities, :product_inventory_warehousess
            )
          products.update_all(status: params[:status])
          products.reload

          eager_loaded_obj = Product.generate_eager_loaded_obj(products)

          bulk_action.update(total: products.length, completed: 0, status: 'in_progress')
          (products || []).find_each(batch_size: 100) do |product|
            # product = Product.find(single_product['id'])
            bulk_action.reload
            if bulk_action.cancel?
              bulk_action.update(status: 'cancelled')
              return true
            end
            bulk_action.update(current: product.name)
            current_status = product.status
            if product.status == params[:status]
              if product.status != 'inactive'
                if !product.update_product_status(nil, eager_loaded_obj) && params[:status] == 'active'
                  current_status = product.status
                  result['status'] &= false
                  if product.is_kit == 1
                    result['messages'].push('There was a problem changing kit status for ' +
                                              product.name + '. Reason: In order for a Kit to be Active it needs to ' \
                                              'have at least one item and every item in the Kit must be Active.')
                  else
                    result['messages'].push('There was a problem changing product status for ' +
                                              product.name + '. Reason: In order for a product to be Active it needs to ' \
                                              'have at least one SKU and one barcode.')
                  end
                  product.update_column(:status, current_status)
                end
              else
                product.update_due_to_inactive_product
              end
            else
              result['status'] &= false
              result['messages'].push('There was a problem changing products status for ' + product.name)
            end
            bulk_action.update(completed: bulk_action.completed + 1)
          end
          unless bulk_action.cancel?
            bulk_action_status = result['status'] ? 'completed' : 'failed'
            bulk_action.update(status: bulk_action_status, messages: result['messages'], current: '')
          end
        rescue Exception => e
          bulk_action.update(status: 'failed', messages: ['Some error occurred'], current: '')
        end
      end

      def delete(tenant, params, bulk_actions_id, username)
        Apartment::Tenant.switch!(tenant)
        result = {}
        result['messages'] = []
        result['status'] = true
        bulk_action = GrooveBulkActions.find(bulk_actions_id)
        Ahoy::Event.create(version_2: true, time: Time.current,
                           properties: { title: 'Product Removal Start', tenant:, username: })
        time_started = Time.current
        begin
          products =
            list_selected_products(params)
            .includes(
              :product_barcodes, :product_skus, :product_cats, :product_images,
              :store, :product_kit_skuss, :product_inventory_warehousess,
              order_items: [:order]
            )

          first_25_products = products.limit(25).collect do |product|
            product.primary_sku || product.primary_barcode || product.name
          end
          products_count = products.count
          products_kit_skus =
            ProductKitSkus.where(option_product_id: products.map(&:id))
                          .includes(product: :product_kit_skuss)

          bulk_action.total = products.length
          bulk_action.completed = 0
          bulk_action.status = 'in_progress'
          bulk_action.save

          products.each do |product|
            bulk_action.reload
            if bulk_action.cancel?
              bulk_action.status = 'cancelled'
              bulk_action.save
              return true
            end
            bulk_action.current = product.name
            bulk_action.save
            product.order_items.each do |order_item|
              next unless order_item.order.present?

              if order_item.order.status != 'scanned' && order_item.order.status != 'cancelled' && !order_item.order.nil?
                order_item.order.status = 'onhold'
                order_item.order.save
              end
              if order_item.order.present?
                order_item.order.addactivity(
                  "An item with Name #{product.name} and " + "SKU #{product.primary_sku} has been deleted", username, 'deleted_item'
                )
              end
              order_item.destroy
            end

            products_kit_skus
              .select { |pkss| pkss.option_product_id == product.id }
              .each do |product_kit_sku|
                product_kit_sku.product.status = 'new'
                product_kit_sku.product.save
                product_kit_sku.product.product_kit_activities.create(
                  activity_message: "An item with Name #{product.name} and " \
                    "SKU #{product.primary_sku} has been deleted",
                  username:,
                  activity_type: 'deleted_item'
                )
                product_kit_sku.destroy
            rescue StandardError
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

          unless bulk_action.cancel?
            bulk_action.status = result['status'] ? 'completed' : 'failed'
            bulk_action.messages = result['messages']
            bulk_action.current = ''
            bulk_action.save
          end

          total_elapsed_time = (Time.current - time_started).round(2)
          object_per_sec = total_elapsed_time * 60 / products_count

          Ahoy::Event.create(version_2: true, time: Time.current,
                             properties: { title: 'Product Removal End', tenant:, username:, objects_involved_count: products_count, objects_involved: first_25_products, elapsed_time: total_elapsed_time, object_per_sec: })

          begin
            Ahoy::Event.version_2.create({
                                           name: 'List of Deleted Products (25)',
                                           properties: {
                                             title: 'List of Deleted Products (25)',
                                             tenant: Apartment::Tenant.current,
                                             username:,
                                             objects_involved: first_25_products,
                                             objects_involved_count: products_count
                                           },
                                           time: Time.current
                                         })
          rescue StandardError
            nil
          end
        rescue Exception => e
          bulk_action.status = 'failed'
          bulk_action.messages = ['Some error occurred']
          bulk_action.current = ''
          bulk_action.save
        end
      end

      def duplicate(tenant, params, bulk_actions_id)
        Apartment::Tenant.switch!(tenant)
        result = {}
        result['messages'] = []
        result['status'] = true
        bulk_action = GrooveBulkActions.find(bulk_actions_id)

        begin
          products = list_selected_products(params)
          bulk_action.total = products.length
          bulk_action.completed = 0
          bulk_action.status = 'in_progress'
          bulk_action.save
          products.each do |product|
            # copy product
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
            newproduct.name = product.name + ' ' + index.to_s
            productslist = Product.where(name: newproduct.name)
            begin
              index += 1
              # TODO: duplicate sku, images, categories associated with product too.
              newproduct.name = product.name + ' ' + index.to_s
              productslist = Product.where(name: newproduct.name)
            end while (productslist.present?)

            # copy barcodes
            product.product_barcodes.each do |barcode|
              index = 0
              newbarcode = barcode.barcode + ' ' + index.to_s
              barcodeslist = ProductBarcode.where(barcode: newbarcode)
              begin
                index += 1
                # TODO: duplicate sku, images, categories associated with product too.
                newbarcode = barcode.barcode + ' ' + index.to_s
                barcodeslist = ProductBarcode.where(barcode: newbarcode)
              end while (barcodeslist.present?)

              newbarcode_item = ProductBarcode.new
              newbarcode_item.barcode = newbarcode
              newproduct.product_barcodes << newbarcode_item
            end

            # copy skus
            product.product_skus.each do |sku|
              index = 0
              newsku = sku.sku + ' ' + index.to_s
              skuslist = ProductSku.where(sku: newsku)
              begin
                index += 1
                # TODO: duplicate sku, images, categories associated with product too.
                newsku = sku.sku + ' ' + index.to_s
                skuslist = ProductSku.where(sku: newsku)
              end while (skuslist.present?)

              newsku_item = ProductSku.new
              newsku_item.sku = newsku
              newsku_item.purpose = sku.purpose
              newproduct.product_skus << newsku_item
            end

            # copy images
            product.product_images.each do |image|
              newimage = ProductImage.new
              newimage = image.dup
              newproduct.product_images << newimage
            end

            # copy categories
            product.product_cats.each do |category|
              newcategory = ProductCat.new
              newcategory = category.dup
              newproduct.product_cats << newcategory
            end

            # copy product kit items
            product.product_kit_skuss.each do |sku|
              new_kit_sku = ProductKitSkus.new
              new_kit_sku = sku.dup
              newproduct.product_kit_skuss << new_kit_sku
            end

            # copy product inventory warehouses
            product.product_inventory_warehousess.each do |warehouse|
              new_warehouse = ProductInventoryWarehouses.new
              new_warehouse = warehouse.dup
              newproduct.product_inventory_warehousess << new_warehouse
            end

            unless newproduct.save(validate: false)
              result['status'] = false
              result['messages'] = newproduct.errors.full_messages
            end
            bulk_action.completed = bulk_action.completed + 1
            bulk_action.save
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

      def export(tenant, _params, bulk_actions_id, user)
        require 'csv'

        Apartment::Tenant.switch!(tenant)
        result = {}
        result['messages'] = []
        result['status'] = true
        bulk_action = GrooveBulkActions.find(bulk_actions_id)
        begin
          dir = Dir.mktmpdir([user + 'groov-export-', Time.current.to_s])
          filename = 'groove-export-' + Time.current.to_s + '.zip'
          response = {}
          tables = {
            products: Product,
            product_barcodes: ProductBarcode,
            product_images: ProductImage,
            product_skus: ProductSku,
            product_cats: ProductCat,
            product_kit_skus: ProductKitSkus,
            product_inventory_warehouses: ProductInventoryWarehouses
          }
          bulk_action.total = 0
          bulk_action.completed = 0
          bulk_action.status = 'not_started'
          bulk_action.save
          tables.each do |ident, model|
            bulk_action.reload
            if bulk_action.cancel == true
              bulk_action.status = 'cancelled'
              bulk_action.save
              return true
            end
            bulk_action.total = model.all.count
            bulk_action.status = 'in_progress'
            bulk_action.current = ident.to_s.camelize
            bulk_action.completed = 0
            bulk_action.save!
            sleep(1) unless Rails.env.test?
            CSV.open("#{dir}/#{ident}.csv", 'w') do |csv|
              headers = []
              if ident == :products
                ProductsHelper.products_csv(model.all, csv, bulk_actions_id, true)
              else
                headers = model.column_names.dup

                csv << headers

                model.all.each do |item|
                  bulk_action.reload
                  if bulk_action.cancel == true
                    bulk_action.status = 'cancelled'
                    bulk_action.save
                    return true
                  end
                  bulk_action.completed = bulk_action.completed + 1
                  bulk_action.save
                  data = []
                  data = item.attributes.values_at(*model.column_names).dup

                  csv << data
                end
              end
              response[ident] = "#{dir}/#{ident}.csv"
            end
          end
          data = zip_to_files(filename, response)
          unless bulk_action.cancel?
            bulk_action.status = result['status'] ? 'completed' : 'failed'
            bulk_action.messages = result['messages']
            bulk_action.current = ''
            bulk_action.save
          end
          GroovS3.create_export_csv(tenant, filename, data)
          url = GroovS3.find_export_csv(tenant, filename)
          CsvExportMailer.send_s3_object_url(filename, url, tenant).deliver
        rescue Exception => e
          puts e.message
          puts e.backtrace
          bulk_action.status = 'failed'
          bulk_action.messages = ['Some error occurred']
          bulk_action.save
        ensure
          FileUtils.remove_entry_secure dir
        end
      end
    end
  end
end
