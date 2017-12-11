module Groovepacker
    module Orders
      module Xml
        class OrderXml
          attr_accessor :doc, :file_handle, :file_name
          
          def initialize(file_name)
            @file_name = file_name
            @file_handle = File.open(Rails.root.join('public', 'csv', file_name))
            @doc = File.open(Rails.root.join('public', 'csv', file_name)) { |f| Nokogiri::XML(f) }
            # puts doc.xpath("//order/storeId").text.inspect
        
            # doc.xpath("//order/orderItems").each do |order_item|
            # puts order_item.xpath("//orderItem/qty").text.inspect
            # end
          end

          def save
            GroovS3.create_order_xml(Apartment::Tenant.current, @file_name, @file_handle.read)
          end

          def total_count
            number(@doc, "//order/@total")
          end

          def store_id
            text(@doc, "//order/storeId")
          end

          def increment_id
            text(@doc, "//order/incrementId")
          end

          def firstname
            text(@doc, "//order/customerInformation/firstName")
          end

          def lastname
            text(@doc, "//order/customerInformation/lastName")
          end

          def email
            text(@doc, "//order/customerInformation/email")
          end

          def address_1
            text(@doc, "//order/shippingAddress/address1")           
          end

          def address_2
            text(@doc, "//order/shippingAddress/address2")           
          end

          def city
            text(@doc, "//order/shippingAddress/city")            
          end

          def state
            text(@doc, "//order/shippingAddress/state")            
          end

          def country
            text(@doc, "//order/shippingAddress/country")            
          end

          def postcode
            text(@doc, "//order/shippingAddress/postcode")
          end

          def order_placed_time
            date(@doc, "//order/orderPlacedTime")
          end

          def tracking_num
            text(@doc, "//order/trackingNum")
          end

          def import_summary_id
            number(@doc, "//order/importSummaryId")
          end

          def custom_field_one
            text(@doc, "//order/customFieldOne")
          end

          def custom_field_two
            text(@doc, "//order/customFieldTwo")
          end

          def method
            text(@doc, "//order/method")
          end

          def order_total
            text(@doc, "//order/orderTotal")
          end

          def customer_comments
            text(@doc, "//order/customerComments")
          end

          def notes_toPacker
            text(@doc, "//order/notesToPacker")
          end

          def notes_fromPacker
            text(@doc, "//order/notesFromPacker")
          end

          def notes_internal
            text(@doc, "//order/notesInternal")
          end

          def order_items
            orderItems = []
            puts @doc.xpath("//order/orderItems/orderItem").length
            @doc.xpath("//order/orderItems/orderItem").each do |orderItemXml|
              orderItem = {}
              orderItem[:qty] = text(orderItemXml, "qty")
              orderItem[:price] = text(orderItemXml, "price")
              orderItem[:product] = product(orderItemXml)
              orderItems.push(orderItem)
            end
            orderItems
          end

          private

          def date(node, xpath)
            node.xpath(xpath).text == "" ? nil : DateTime.parse(node.xpath(xpath).text)
          end

          def text(node, xpath)
            node.xpath(xpath).text == "" ? nil : node.xpath(xpath).text
          end

          def text_at(node, path)
            node.at(path).text == "" ? nil : node.at(path).text
          end

          def number(node, xpath)
            node.xpath(xpath).text == "" ? nil : node.xpath(xpath).text.to_i
          end

          def parse_text(text)
            text == "" ? nil : text
          end

          def product(node)
            product = {}
            product[:name] = text_at(node, "product > name")
            product[:price] = text_at(node, "product > price")
            product[:instructions] = text_at(node, "product > instructions")
            product[:weight] = text_at(node, "product > weight").nil? ? 0 : text_at(node, "product > weight")
            puts text_at(node, "product > weight").inspect
            product[:weight_format] = text_at(node, "product > weight > @unit")
            product[:is_kit] = text_at(node, "product > isKit")
            product[:kit_parsing] = text_at(node, "product > kitParsing")
            product[:skus] = []
            unless node.at("product > skus").nil?
              node.at("product > skus").xpath("sku").each do |skuElement|
                product[:skus].push(parse_text(skuElement.text)) unless parse_text(skuElement.text).nil?
              end
            end
            product[:images] = []
            unless node.at("product > images").nil?
              node.at("product > images").xpath("image").each do |imageElement|
                product[:images].push(parse_text(imageElement.text)) unless parse_text(imageElement.text).nil?
              end
            end
            product[:categories] = []
            unless node.at("product > categories").nil?
              node.at("product > categories").xpath("category").each do |categoryElement|
                product[:categories].push(parse_text(categoryElement.text)) unless parse_text(categoryElement.text).nil?
              end
            end
            product[:barcodes] = []
            unless node.at("product > barcodes").nil?
              node.at("product > barcodes").xpath("barcode").each do |barcodeElement|
                product[:barcodes].push(parse_text(barcodeElement.text)) unless parse_text(barcodeElement.text).nil?
              end
            end
            product
          end
        end
      end
    end
end
