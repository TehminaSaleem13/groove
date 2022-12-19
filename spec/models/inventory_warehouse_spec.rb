# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InventoryWarehouse, type: :model do
  it 'inventory warehouse should have many users' do
    inventory_warehouse = described_class.reflect_on_association(:users)
    expect(inventory_warehouse.macro).to eq(:has_many)
  end

  it 'inventory warehouse should have many user_inventory_permissions' do
    inventory_warehouse = described_class.reflect_on_association(:user_inventory_permissions)
    expect(inventory_warehouse.macro).to eq(:has_many)
  end

  it 'inventory warehouse should have many product inventory warehousess' do
    inventory_warehouse = described_class.reflect_on_association(:product_inventory_warehousess)
    expect(inventory_warehouse.macro).to eq(:has_many)
  end

  it 'inventory warehouse should have many stores' do
    inventory_warehouse = described_class.reflect_on_association(:stores)
    expect(inventory_warehouse.macro).to eq(:has_many)
  end

  describe InventoryWarehouse do
    it 'inventory warehouse must have name' do
      inventory_warehouse = described_class.create(name: '')
      inventory_warehouse.valid?
      inventory_warehouse.errors.should have_key(:name)
    end
  end

  describe InventoryWarehouse do
    it 'inventory warehouse must presence uniq name' do
      described_class.create(name: 'Default_inventory')
      inventory_warehouse = described_class.new(name: 'Primary_inventory')
      inventory_warehouse.should be_valid
    end

    it 'Check Update Fields' do
      user = User.create(username: 'kapil2', active: true, other: nil, name: 'kapil2', confirmation_code: '8460', role_id: 4, view_dashboard: 'packer_dashboard', is_deleted: false, reset_token: nil, email: 'kapiltest@yomail.com', last_name: nil, custom_field_one: nil, custom_field_two: nil, dashboard_switch: false, warehouse_postcode: nil)
      inv_wh = FactoryBot.create(:inventory_warehouse, name: 'csv_inventory_warehouse', is_default: 1)
      user_inventory_permissions = UserInventoryPermission.new(user_id: user.id, inventory_warehouse_id: inv_wh.id, see: false, edit: true)
      user_inventory_permissions.run_callbacks :save
      user_inventory_permissions.check_update_fields
      expect(user_inventory_permissions.see).to eq(true)
    end
  end
end
