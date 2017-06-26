class CreateGenerateBarcodes < ActiveRecord::Migration
  def change
  	unless table_exists? :generate_barcodes
	    create_table :generate_barcodes do |t|
	      t.string :status
	      t.string :url

	      t.timestamps
	    end
	end
  end
end
