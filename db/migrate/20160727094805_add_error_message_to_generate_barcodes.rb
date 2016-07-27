class AddErrorMessageToGenerateBarcodes < ActiveRecord::Migration
  def change
    add_column :generate_barcodes, :error_message, :text
  end
end
