class AddRandomNoToSubsction < ActiveRecord::Migration
  def change
  	add_column :subscriptions, :shopify_payment_token, :string
  end
end
