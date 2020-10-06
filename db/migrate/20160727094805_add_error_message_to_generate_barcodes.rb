class AddErrorMessageToGenerateBarcodes < ActiveRecord::Migration[5.1]
  def change
    unless column_exists? :generate_barcodes, :error_message
      add_column :generate_barcodes, :error_message, :text
    end
  end
end
