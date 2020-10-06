class AddApiCallToTenant < ActiveRecord::Migration[5.1]
  def change
    add_column :tenants, :api_call, :boolean, :default => false
  end
end
