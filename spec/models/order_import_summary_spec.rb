require 'rails_helper'

RSpec.describe OrdersImportSummary, type: :model do
  it 'order import summary should belongs to store' do
    order_import_summary = OrdersImportSummary.reflect_on_association(:store)
    expect(order_import_summary.macro).to eq(:belongs_to)
  end

  it 'order import summary should have many import items' do
    order_import_summary = OrderImportSummary.reflect_on_association(:import_items)
    expect(order_import_summary.macro).to eq(:has_many)
  end

  it 'order import summary should belongs to user' do
    order_import_summary = OrderImportSummary.reflect_on_association(:user)
    expect(order_import_summary.macro).to eq(:belongs_to)
  end
end
