class AddHeightAndWidthToPrintPdfLinks < ActiveRecord::Migration[5.1]
  def change
    add_column :print_pdf_links, :height, :integer
    add_column :print_pdf_links, :width, :integer
  end
end
