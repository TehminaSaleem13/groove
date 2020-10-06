class AddTransactionIdToSubscriptions < ActiveRecord::Migration[5.1]
  def up
    add_column :subscriptions, :transaction_id, :string
  end
  def down
  	remove_column :subscriptions, :transaction_id
  end
end
