class AddThankYouMessageToCustomerToStores < ActiveRecord::Migration
  def up
    add_column :stores, :thank_you_message_to_customer, :text
  end
  def down
  	remove_column :stores, :thank_you_message_to_customer
  end
end
