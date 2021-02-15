require 'rails_helper'

RSpec.describe CsvImportSummary, type: :model do
  it 'csv import summary should have many csv_import_log_entries' do
    csv_import_summary = CsvImportSummary.reflect_on_association(:csv_import_log_entries)
    expect(csv_import_summary.macro).to eq(:has_many)
  end
end
