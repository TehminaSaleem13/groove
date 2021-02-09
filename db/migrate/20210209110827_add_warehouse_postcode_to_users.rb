class AddWarehousePostcodeToUsers < ActiveRecord::Migration[5.1]
  def change
    add_column :users, :warehouse_postcode, :string, default: ''
  end
end
