require 'rails_helper'

RSpec.describe ToteSet, type: :model do
  describe ToteSet do
      it 'Tote Set Should Have Many Tote Sets' do
        t = ToteSet.reflect_on_association(:totes)
        expect(t.macro).to eq(:has_many)
      end
    end
end
