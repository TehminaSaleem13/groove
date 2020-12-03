class AddApiCreateLabelToTenants < ActiveRecord::Migration[5.1]
  def change
    add_column :tenants, :ss_api_create_label, :boolean, default: false
  end
end
