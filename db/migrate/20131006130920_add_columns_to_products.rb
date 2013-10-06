class AddColumnsToProducts < ActiveRecord::Migration
  def change
    add_column :products, :inv_wh1, :string
    add_column :products, :location_primary, :string
  end
end
