class AddBaseSkuToProducts < ActiveRecord::Migration
  def change
    add_column :products, :base_sku, :string
  end
end
