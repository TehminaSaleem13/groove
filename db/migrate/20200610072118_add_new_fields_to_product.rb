class AddNewFieldsToProduct < ActiveRecord::Migration
  def change
    add_column :products, :fnsku, :string unless column_exists? :products, :fnsku
    add_column :products, :asin, :string unless column_exists? :products, :asin
    add_column :products, :fba_upc, :string unless column_exists? :products, :fba_upc
    add_column :products, :isbn, :string unless column_exists? :products, :isbn
    add_column :products, :ean, :string unless column_exists? :products, :ean
    add_column :products, :supplier_sku, :string unless column_exists? :products, :supplier_sku
    add_column :products, :avg_cost, :decimal, :precision => 10, :scale => 2 unless column_exists? :products, :avg_cost
    add_column :products, :count_group, :string, :limit => 1 unless column_exists? :products, :count_group
  end
end
