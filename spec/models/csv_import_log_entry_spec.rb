# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CsvImportLogEntry, type: :model do
  it 'csv import log entry should belongs to csv import summary' do
    csv_import_log_entries = described_class.reflect_on_association(:csv_import_summary)
    expect(csv_import_log_entries.macro).to eq(:belongs_to)
  end
end
