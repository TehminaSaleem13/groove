class CreatePrintPdfLinks < ActiveRecord::Migration[5.1]
  def change
    create_table :print_pdf_links do |t|
      t.longtext :url
      t.boolean :is_pdf_printed, default: false
      t.string :pdf_name

      t.timestamps
    end
  end
end
