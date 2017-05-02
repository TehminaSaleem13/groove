class CsvImportSummary < ActiveRecord::Base
  attr_accessible :file_name, :file_size, :import_type
  has_many :csv_import_log_entries, :dependent => :destroy
end
