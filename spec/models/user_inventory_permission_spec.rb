require 'rails_helper'

RSpec.describe UserInventoryPermission, type: :model do
  describe UserInventoryPermission do
    it 'user inventory permission should belongs to  inventory warehouses' do
      t = UserInventoryPermission.reflect_on_association(:inventory_warehouse)
      expect(t.macro).to eq(:belongs_to)
    end
  end
  
  describe UserInventoryPermission do
    it 'user inventory permission should belongs to  user' do
      t = UserInventoryPermission.reflect_on_association(:user)
      expect(t.macro).to eq(:belongs_to)
    end

    it 'Check Update Fields' do
      user = User.create(username: "kapil2", active: true, other: nil, name: "kapil2", confirmation_code: "8460", role_id: 4, view_dashboard: "packer_dashboard", is_deleted: false, reset_token: nil, email: "kapiltest@yomail.com", last_name: nil, custom_field_one: nil, custom_field_two: nil, dashboard_switch: false, warehouse_postcode: nil)
      inv_wh = FactoryBot.create(:inventory_warehouse, name: 'csv_inventory_warehouse', is_default: 1)
      user_inventory_permissions = UserInventoryPermission.new(user_id: user.id, inventory_warehouse_id: inv_wh.id, see: false, edit: true)
      user_inventory_permissions.run_callbacks :save 
      user_inventory_permissions.check_update_fields
      expect(user_inventory_permissions.see).to eq(true)
    end
  end 
end
