# frozen_string_literal: true

module Groovepacker
  module Stores
    module Importers
      module MagentoRest
        class ProductsImporter < Groovepacker::Stores::Importers::Importer
          include ProductsHelper

          def import
            result = get_importer.import
            update_orders_status
          end

          def import_single(product_attrs = {})
            result = get_importer.import_single(product_attrs)
          end

          private

          def get_importer
            handler = get_handler
            credential = handler[:credential]
            importer = if credential.store_version == '2.x'
                         Groovepacker::Stores::Importers::MagentoRest::V2::ProductsImporter.new(handler)
                       else
                         Groovepacker::Stores::Importers::MagentoRest::V1::ProductsImporter.new(handler)
                       end
            importer
          end
        end
      end
    end
  end
end
