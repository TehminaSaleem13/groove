class CreateTransactions < ActiveRecord::Migration
  def up
    create_table :transactions do |t|
    	t.string :transaction_id
    	t.decimal :amount, :precision => 8, :scale => 2, :default => '0'
    	t.string :card_type
    	t.integer :exp_month_of_card
    	t.integer :exp_year_of_card
    	t.datetime :date_of_payment
    	t.integer :subscription_id

      t.timestamps
    end
  end
  def down
  	drop_table :transactions
  end
end
