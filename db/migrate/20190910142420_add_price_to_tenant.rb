class AddPriceToTenant < ActiveRecord::Migration[5.1]
  def change
    add_column :tenants, :price, :text
  end
end
