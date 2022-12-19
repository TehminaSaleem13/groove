# frozen_string_literal: true

module InventoryWarehouseHelper
  def fix_user_inventory_permissions(user, inventory_warehouse)
    uip = UserInventoryPermission.find_or_create_by(user_id: user.id, inventory_warehouse_id: inventory_warehouse.id)
    uip.see = !(user.can?('make_super_admin') || (user.inventory_warehouse_id == inventory_warehouse.id)).blank?
    uip.edit = !(user.can?('make_super_admin') || ((user.inventory_warehouse_id == inventory_warehouse.id) && user.can?('add_edit_products'))).blank?
    uip.save
    uip
  end
end
