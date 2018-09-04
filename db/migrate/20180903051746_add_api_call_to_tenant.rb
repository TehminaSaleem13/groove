class AddApiCallToTenant < ActiveRecord::Migration
  def change
    add_column :tenants, :api_call, :boolean, :default => false
  end
end
