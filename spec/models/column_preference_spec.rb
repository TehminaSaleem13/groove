# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ColumnPreference, type: :model do
  it 'column preference should belongs to user' do
    column_preference = described_class.reflect_on_association(:user)
    expect(column_preference.macro).to eq(:belongs_to)
  end
end
