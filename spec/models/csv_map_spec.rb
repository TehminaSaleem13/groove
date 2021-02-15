require 'rails_helper'

RSpec.describe CsvMap, type: :model do
  it 'csv map should have one csv_mapping' do
    csv_map = CsvMap.reflect_on_association(:csv_mapping)
    expect(csv_map.macro).to eq(:has_one)
  end

  describe CsvMap do
    it 'csv map must have uniq name' do
      CsvMap.create(name: 'CSVT1')
      csv_map = CsvMap.new(name: 'CSVT1')
      csv_map.should_not be_valid
      csv_map.errors[:name].should include('has already been taken')
    end
  end

  describe CsvMap do
    it 'csv map must have uniq kind' do
      CsvMap.create(kind: 'order')
      csv_map = CsvMap.new(kind: 'order')
      csv_map.should_not be_valid
      csv_map.errors[:name].should include('has already been taken')
    end
  end
end
