class CreateGenerateBarcodes < ActiveRecord::Migration
  def change
    create_table :generate_barcodes do |t|
      t.string :status
      t.string :url

      t.timestamps
    end
  end
end
