class CreateOrderImportSummaries < ActiveRecord::Migration[5.1]
  def up
  	create_table :order_import_summaries do |t|
  		t.integer :user_id
      t.string :status

      t.timestamps
    end
  end

  def down
  	drop_table :order_import_summaries
  end
end
