# frozen_string_literal: true

module Groovepacker
  module Stores
    module Handlers
      class VeeqoHandler < Handler

        def build_handle
          veeqo_credential = VeeqoCredential.where(store_id: store.id).first

          client = Groovepacker::VeeqoRuby::Client.new(veeqo_credential) unless veeqo_credential.nil?
          
          make_handle(veeqo_credential, client)
        end

        def import_orders
          Groovepacker::Stores::Importers::Veeqo::OrdersImporter.new(
            build_handle
          ).import
        end

        def import_single_order_from(order_no)
          Groovepacker::Stores::Importers::Veeqo::OrdersImporter.new(
            build_handle
          ).ondemand_import_single_order(order_no)
        end

        def import_single_product(product)
          Groovepacker::Stores::Importers::Veeqo::ProductsImporter.new(
            build_handle
          ).import_single_product(product)
        end
      end
    end
  end
end
