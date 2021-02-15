require 'rails_helper'

RSpec.describe ProductBarcode, type: :model do
  it 'product barcode should belongs to product' do
    product_barcode = ProductBarcode.reflect_on_association(:product)
    expect(product_barcode.macro).to eq(:belongs_to)
  end

  it 'product barcode should belongs to order item' do
    product_barcode = ProductBarcode.reflect_on_association(:order_item)
    expect(product_barcode.macro).to eq(:belongs_to)
  end

  describe ProductBarcode do
    it 'should have a unique barcode' do
      ProductBarcode.create!(barcode: 'apple-1')
      product_barcode = ProductBarcode.new(barcode: 'apple-1')
      product_barcode.should_not be_valid
      product_barcode.errors[:barcode].should include('has already been taken')
    end
  end
end
