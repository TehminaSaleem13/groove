# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProductBarcode, type: :model do
  it 'product barcode should belongs to product' do
    product_barcode = described_class.reflect_on_association(:product)
    expect(product_barcode.macro).to eq(:belongs_to)
  end

  it 'product barcode should belongs to order item' do
    product_barcode = described_class.reflect_on_association(:order_item)
    expect(product_barcode.macro).to eq(:belongs_to)
  end

  describe ProductBarcode do
    it 'Permit Duplicate Barcodes' do
      described_class.create!(barcode: 'apple-1')
      product_barcode = described_class.new(barcode: 'apple-1', permit_shared_barcodes: true)
      expect(product_barcode).to be_valid
    end
  end
end
