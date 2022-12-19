# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CsvMapping, type: :model do
  it 'csv mapping should belongs to store' do
    csv_mapping = described_class.reflect_on_association(:store)
    expect(csv_mapping.macro).to eq(:belongs_to)
  end

  it 'csv mapping should belongs to product csv_map' do
    csv_mapping = described_class.reflect_on_association(:product_csv_map)
    expect(csv_mapping.macro).to eq(:belongs_to)
  end

  it 'csv mapping should belongs to  order csv map' do
    csv_mapping = described_class.reflect_on_association(:order_csv_map)
    expect(csv_mapping.macro).to eq(:belongs_to)
  end

  it 'csv mapping should belongs to kit csv map' do
    csv_mapping = described_class.reflect_on_association(:kit_csv_map)
    expect(csv_mapping.macro).to eq(:belongs_to)
  end
end
