class CsvImportLogEntry < ActiveRecord::Base
  #attr_accessible :csv_import_summary_id, :index
  belongs_to :csv_import_summary
end
