class AddDimensionToGenerateBarcode < ActiveRecord::Migration[5.1]
  def change
    add_column :generate_barcodes, :dimensions, :string
  end
end
