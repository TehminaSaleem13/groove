# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User, type: :model do
  it 'user should belongs to inventory warehouses' do
    t = described_class.reflect_on_association(:inventory_warehouse)
    expect(t.macro).to eq(:belongs_to)
  end

  it 'user should belongs to role' do
    t = described_class.reflect_on_association(:role)
    expect(t.macro).to eq(:belongs_to)
  end

  it 'user should have many doorkeeper tokens' do
    t = described_class.reflect_on_association(:doorkeeper_tokens)
    expect(t.macro).to eq(:has_many)
  end

  it 'user should have many user inventory permisions' do
    t = described_class.reflect_on_association(:user_inventory_permissions)
    expect(t.macro).to eq(:has_many)
  end

  it 'user should have many order activities' do
    t = described_class.reflect_on_association(:order_activities)
    expect(t.macro).to eq(:has_many)
  end

  it 'user should have many product activities' do
    t = described_class.reflect_on_association(:product_activities)
    expect(t.macro).to eq(:has_many)
  end

  it 'requires username' do
    user = described_class.create(username: '')
    user.valid?
    user.errors.should have_key(:username)
  end

  describe 'Username must be uniq' do
    let(:user) { described_class.new }
    let(:user1) { described_class.new }

    it 'has uniq username' do
      user.username = 'kapil'
      user1.username = 'Kapil'
      expect(user1).not_to be_valid
    end
  end

  it 'requires cofirmation code' do
    user = described_class.create(confirmation_code: '')
    user.valid?
    user.errors.should have_key(:confirmation_code)
  end

  describe 'confimation code must be uniq' do
    let(:user) { described_class.new }
    let(:user1) { described_class.new }

    it 'has uniq username' do
      user.confirmation_code = '1234ab'
      user1.confirmation_code = '1234ab'
      expect(user1).not_to be_valid
    end
  end

  describe 'Confirmation code lenght' do
    let(:user) { described_class.new }

    it 'user confirmation code max lenght must be 25' do
      user.confirmation_code = '12345678912345679123456789'
      expect(user).not_to be_valid
    end
  end
end
