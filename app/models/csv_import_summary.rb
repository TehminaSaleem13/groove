# frozen_string_literal: true

class CsvImportSummary < ActiveRecord::Base
  # attr_accessible :file_name, :file_size, :import_type, :log_record
  has_many :csv_import_log_entries, dependent: :destroy
end
