class CreateInvoices < ActiveRecord::Migration
  def up
    create_table :invoices do |t|
    	t.datetime :date
    	t.string :invoice_id
    	t.string :subscription_id
    	t.decimal :amount, :precision => 8, :scale => 2, :default => '0'
    	t.datetime :period_start
    	t.datetime :period_end
    	t.integer :quantity
    	t.string :plan_id
    	t.string :customer_id
    	t.string :charge_id
    	t.boolean :attempted
    	t.boolean :closed
    	t.boolean :forgiven
    	t.boolean :paid

      t.timestamps
    end
  end
  def down
  	drop_table :invoices
  end
end
