class AddMoreFieldsToTenants < ActiveRecord::Migration
  def change
    add_column :tenants, :initial_plan_id, :string
    add_column :tenants, :addon_notes, :text
  end
end
