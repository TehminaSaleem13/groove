# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CsvMap, type: :model do
  it 'csv map should have one csv_mapping' do
    csv_map = described_class.reflect_on_association(:csv_mapping)
    expect(csv_map.macro).to eq(:has_one)
  end

  describe CsvMap do
    it 'csv map must have uniq name' do
      described_class.create(name: 'CSVT1')
      csv_map = described_class.new(name: 'CSVT1')
      csv_map.should_not be_valid
      csv_map.errors[:name].should include('has already been taken')
    end
  end

  describe CsvMap do
    it 'csv map must have uniq kind' do
      described_class.create(kind: 'order')
      csv_map = described_class.new(kind: 'order')
      csv_map.should_not be_valid
      csv_map.errors[:name].should include('has already been taken')
    end
  end
end
