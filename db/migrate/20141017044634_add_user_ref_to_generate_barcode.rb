class AddUserRefToGenerateBarcode < ActiveRecord::Migration
  def change
    add_column :generate_barcodes, :user_id, :integer, references: :users
    add_column :generate_barcodes, :hash, :string
    add_column :generate_barcodes, :current_increment_id, :string
    add_column :generate_barcodes, :current_order_position, :string
    add_column :generate_barcodes, :total_orders, :string
    add_index :generate_barcodes, :hash
    add_index :generate_barcodes, :user_id
  end
end
