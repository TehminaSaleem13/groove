require 'rails_helper'

RSpec.describe Visit, type: :model do
  describe Visit do
    it 'user should belongs to  inventory warehouses' do
      t = Visit.reflect_on_association(:ahoy_events)
      expect(t.macro).to eq(:has_many)
    end
  end
  
  describe Visit do
    it 'visit should belongs to  user' do
      t = Visit.reflect_on_association(:user)
      expect(t.macro).to eq(:belongs_to)
    end
  end 
end
