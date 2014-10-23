class AddUserRefToGenerateBarcode < ActiveRecord::Migration
  def change
    add_column :generate_barcodes, :user_id, :integer, references: :users
    add_column :generate_barcodes, :hash_value, :string
    add_column :generate_barcodes, :current_increment_id, :string
    add_column :generate_barcodes, :current_order_position, :integer
    add_column :generate_barcodes, :total_orders, :integer
    add_index :generate_barcodes, :hash_value
    add_index :generate_barcodes, :user_id
  end
end
