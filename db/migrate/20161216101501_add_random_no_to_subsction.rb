class AddRandomNoToSubsction < ActiveRecord::Migration[5.1]
  def change
  	add_column :subscriptions, :shopify_payment_token, :string
  end
end
