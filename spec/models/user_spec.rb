require 'rails_helper'

RSpec.describe User, type: :model do
  it 'user should belongs to inventory warehouses' do
    t = User.reflect_on_association(:inventory_warehouse)
    expect(t.macro).to eq(:belongs_to)
  end

  it 'user should belongs to role' do
    t = User.reflect_on_association(:role)
    expect(t.macro).to eq(:belongs_to)
  end

  it 'user should have many doorkeeper tokens' do
    t = User.reflect_on_association(:doorkeeper_tokens)
    expect(t.macro).to eq(:has_many)
  end

  it 'user should have many user inventory permisions' do
    t = User.reflect_on_association(:user_inventory_permissions)
    expect(t.macro).to eq(:has_many)
  end

  it 'user should have many order activities' do
    t = User.reflect_on_association(:order_activities)
    expect(t.macro).to eq(:has_many)
  end

  it 'user should have many product activities' do
    t = User.reflect_on_association(:product_activities)
    expect(t.macro).to eq(:has_many)
  end

  it 'should require username' do
    user = User.create(username: '')
    user.valid?
    user.errors.should have_key(:username)
  end

  describe 'Username must be uniq' do
    let(:user) { User.new }
    let(:user1) { User.new }
    it 'should have uniq username' do
      user.username = 'kapil'
      user1.username = 'Kapil'
      expect(user1).not_to be_valid
    end
  end

  it 'should require cofirmation code' do
    user = User.create(confirmation_code: '')
    user.valid?
    user.errors.should have_key(:confirmation_code)
  end

  describe 'confimation code must be uniq' do
    let(:user) { User.new }
    let(:user1) { User.new }
    it 'should have uniq username' do
      user.confirmation_code = '1234ab'
      user1.confirmation_code = '1234ab'
      expect(user1).not_to be_valid
    end
  end

  describe 'Confirmation code lenght' do
    let(:user) { User.new }

    it 'user confirmation code max lenght must be 25' do
      user.confirmation_code = '12345678912345679123456789'
      expect(user).not_to be_valid
    end
  end
end
