module Groovepacker
  module Stores
    module Importers
      module Shipstation
        class ImagesImporter < Groovepacker::Stores::Importers::Importer
          def import
            handler = self.get_handler
            credential = handler[:credential]
            client = handler[:store_handle]
            result = self.build_result

            begin
              store = credential.store
              products = store.products.all

              unless products.nil?
                result[:total_imported] = products.length
                products.each do |product|
                  if ProductImage.where(:product_id => product.id).length==0
                    image = ProductImage.new
                    product_skus = product.product_skus
                    unless product_skus.nil?
                      product_sku = product_skus.first
                      order_items = client.order_items.where("SKU" => product_sku.sku)
                      unless order_items.nil?
                        unless order_items.first.nil?
                          unless order_items.first.thumbnail_url.nil?
                            image.image = order_items.first.thumbnail_url
                            product.product_images << image
                            product.save
                            result[:success_imported] = result[:success_imported] + 1
                          end
                        end
                      end
                    end
                  else
                    result[:previous_imported] = result[:previous_imported] + 1
                  end
                end
              end
            rescue Exception => e
              result[:status] &= false
              result[:messages].push(e.message)
            end
            result
          end
        end
      end
    end
  end
end
