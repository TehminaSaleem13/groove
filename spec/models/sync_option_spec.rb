# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SyncOption, type: :model do
  describe SyncOption do
    it 'sync option should belongs to  product' do
      t = described_class.reflect_on_association(:product)
      expect(t.macro).to eq(:belongs_to)
    end
  end
end
