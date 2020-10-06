class CreateGenerateBarcodes < ActiveRecord::Migration[5.1]
  def change
    create_table :generate_barcodes do |t|
      t.string :status
      t.string :url

      t.timestamps
    end
  end
end
