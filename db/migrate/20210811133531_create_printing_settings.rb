class CreatePrintingSettings < ActiveRecord::Migration[5.1]
  def change
    create_table :printing_settings do |t|
      t.string :product_barcode_label_size, default: '3 x 1'

       t.timestamps
    end
  end
end
