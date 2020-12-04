class AddTypeToGenerateBarcode < ActiveRecord::Migration[5.1]
  def change
    add_column :generate_barcodes, :print_type, :string
  end
end
