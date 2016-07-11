module Groovepacker
  module Stores
    module Importers
      module CSV
        class CsvBaseImporter
          def initialize(params, final_record, mapping, import_action)
            self.params = params
            self.final_record = final_record
            self.mapping = mapping
            self.import_action = import_action
          end

          def import
            
          end

          def build_result
            {
              status: true,
              messages: []
            }
          end

          def update_orders_status
            result = { 'status' => true, 'messages' => [], 'error_messages' => [], 'success_messages' => [], 'notice_messages' => [] }
            Groovepacker::Orders::BulkActions.new.delay.update_bulk_orders_status(result, {}, Apartment::Tenant.current)
          end

          protected
          attr_accessor :params, :final_record, :mapping, :import_action
        end
      end
    end
  end
end