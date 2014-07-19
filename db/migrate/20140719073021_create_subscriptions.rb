class CreateSubscriptions < ActiveRecord::Migration
  def change
    create_table :subscriptions do |t|
      t.string :email
      t.string :card_number
      t.integer :card_code
      t.integer :card_month
      t.integer :card_year
      t.string :stripe_customer_token

      t.timestamps
    end
  end
end
