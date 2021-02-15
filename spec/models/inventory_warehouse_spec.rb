require 'rails_helper'

RSpec.describe InventoryWarehouse, type: :model do
  it 'inventory warehouse should have many users' do
    inventory_warehouse = InventoryWarehouse.reflect_on_association(:users)
    expect(inventory_warehouse.macro).to eq(:has_many)
  end

  it 'inventory warehouse should have many user_inventory_permissions' do
    inventory_warehouse = InventoryWarehouse.reflect_on_association(:user_inventory_permissions)
    expect(inventory_warehouse.macro).to eq(:has_many)
  end

  it 'inventory warehouse should have many product inventory warehousess' do
    inventory_warehouse = InventoryWarehouse.reflect_on_association(:product_inventory_warehousess)
    expect(inventory_warehouse.macro).to eq(:has_many)
  end

  it 'inventory warehouse should have many stores' do
    inventory_warehouse = InventoryWarehouse.reflect_on_association(:stores)
    expect(inventory_warehouse.macro).to eq(:has_many)
  end

  describe InventoryWarehouse do
    it 'inventory warehouse must have name' do
      inventory_warehouse = InventoryWarehouse.create(name: '')
      inventory_warehouse.valid?
      inventory_warehouse.errors.should have_key(:name)
    end
  end

  describe InventoryWarehouse do
    it 'inventory warehouse must presence uniq name' do
      InventoryWarehouse.create(name: 'Default_inventory')
      inventory_warehouse = InventoryWarehouse.new(name: 'Primary_inventory')
      inventory_warehouse.should be_valid
    end
  end
end
