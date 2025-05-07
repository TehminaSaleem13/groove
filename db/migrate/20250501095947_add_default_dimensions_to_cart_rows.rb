class AddDefaultDimensionsToCartRows < ActiveRecord::Migration[6.1]
  def change
    add_column :cart_rows, :default_width, :float, default: 0.0
    add_column :cart_rows, :default_height, :float, default: 0.0
    add_column :cart_rows, :default_weight, :float, default: 0.0
  end
end

