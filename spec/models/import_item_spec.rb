# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ImportItem, type: :model do
  it 'import item should belongs to order import summary' do
    import_item = described_class.reflect_on_association(:order_import_summary)
    expect(import_item.macro).to eq(:belongs_to)
  end

  it 'import item should belongs to store' do
    import_item = described_class.reflect_on_association(:store)
    expect(import_item.macro).to eq(:belongs_to)
  end
end
