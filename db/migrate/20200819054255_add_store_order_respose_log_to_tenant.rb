class AddStoreOrderResposeLogToTenant < ActiveRecord::Migration[5.1]
  def change
    add_column :tenants, :store_order_respose_log, :boolean, default: false
  end
end
