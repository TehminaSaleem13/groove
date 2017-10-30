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

          def order_items
            orderItems = []
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

          def text(node, xpath)
            node.xpath(xpath).text == "" ? nil : node.xpath(xpath).text
          end

          def parse_text(text)
            text == "" ? nil : text
          end

          def product(node)
            product = {}
            product[:name] = text(node, "//product/name")
            product[:price] = text(node, "//product/price")
            product[:instructions] = text(node, "//product/instructions")
            product[:weight] = text(node, "//product/weight")
            product[:is_kit] = text(node, "//product/isKit")
            product[:kit_parsing] = text(node, "//product/kitParsing")
            product[:skus] = []
            node.xpath("//product/skus/sku").each do |skuElement|
              product[:skus].push(parse_text(skuElement.text)) unless parse_text(skuElement.text).nil?
            end
            product[:images] = []
            node.xpath("//product/images/image").each do |imageElement|
              product[:images].push(parse_text(imageElement.text)) unless parse_text(imageElement.text).nil?
            end
            product[:categories] = []
            node.xpath("//product/categories/category").each do |categoryElement|
              product[:categories].push(parse_text(categoryElement.text)) unless parse_text(categoryElement.text).nil?
            end
            product[:barcodes] = []
            node.xpath("//product/barcodes/barcode").each do |barcodeElement|
              product[:barcodes].push(parse_text(barcodeElement.text)) unless parse_text(barcodeElement.text).nil?
            end
            product
          end
        end
      end
    end
end
