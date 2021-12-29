class AddPackingCamToTenant < ActiveRecord::Migration[5.1]
  def change
     add_column :tenants, :packing_cam, :boolean, default: false
  end
end
