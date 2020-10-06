class AddErrorsToSubscriptions < ActiveRecord::Migration[5.1]
  def up
    add_column :subscriptions, :transaction_errors, :text
  end
  def down
  	remove_column :subscriptions, :transaction_errors
  end
end
