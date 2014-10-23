class AddMoreColumnsToGenerateBarcodes < ActiveRecord::Migration
  def up
    add_column :generate_barcodes, :cancel, :boolean, default: false
    add_column :generate_barcodes, :next_order_increment_id, :string
    add_column :generate_barcodes, :delayed_job_id, :integer
    remove_column :generate_barcodes, :hash_value
  end
  def down
    remove_column :generate_barcodes, :cancel
    remove_column :generate_barcodes, :next_order_increment_id
    remove_column :generate_barcodes, :delayed_job_id
    add_column :generate_barcodes, :hash_value,:string
  end
end
