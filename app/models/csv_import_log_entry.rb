# frozen_string_literal: true

class CsvImportLogEntry < ApplicationRecord
  # attr_accessible :csv_import_summary_id, :index
  belongs_to :csv_import_summary , optional: true
end
