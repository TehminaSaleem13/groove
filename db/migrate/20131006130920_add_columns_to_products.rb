class AddColumnsToProducts < ActiveRecord::Migration[5.1]
  def change
    add_column :products, :inv_wh1, :string
    add_column :products, :location_primary, :string
  end
end
