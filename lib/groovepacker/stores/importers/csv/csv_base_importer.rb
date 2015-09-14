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

					protected
      		attr_reader :params, :final_record, :mapping, :import_action
				end
			end
		end
	end
end