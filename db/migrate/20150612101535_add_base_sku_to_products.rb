class AddBaseSkuToProducts < ActiveRecord::Migration[5.1]
  def change
    add_column :products, :base_sku, :string
  end
end
