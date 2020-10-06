class AddSomeColumnsToProducts < ActiveRecord::Migration[5.1]
  def change
    add_column :products, :custom_product_1, :string
    add_column :products, :custom_product_2, :string
    add_column :products, :custom_product_3, :string
    add_column :products, :custom_product_display_1, :boolean, default: false
    add_column :products, :custom_product_display_2, :boolean, default: false
    add_column :products, :custom_product_display_3, :boolean, default: false
  end
end
