# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProductInventoryWarehouses, type: :model do
  it 'product inventory warehouses should belongs to product ' do
    productinventorywarehouses = described_class.reflect_on_association(:product)
    expect(productinventorywarehouses.macro).to eq(:belongs_to)
  end

  it 'product inventory warehouses should belongs to inventory warehouses' do
    productinventorywarehouses = described_class.reflect_on_association(:inventory_warehouse)
    expect(productinventorywarehouses.macro).to eq(:belongs_to)
  end
end
