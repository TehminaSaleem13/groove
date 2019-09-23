class AddPriceToTenant < ActiveRecord::Migration
  def change
    add_column :tenants, :price, :text
  end
end
