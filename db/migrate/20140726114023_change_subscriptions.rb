class ChangeSubscriptions < ActiveRecord::Migration
  def up
  	drop_table :subscriptions
  	create_table :subscriptions do |t|
      t.string :email
      t.string :tenant_name
      t.decimal :amount, :precision => 8, :scale => 2, :default => '0'
      t.string :stripe_user_token
      t.string :status
      t.integer :tenant_id
      t.string :stripe_transaction_identifier

      t.timestamps
    end
  end

  def down
  	drop_table :subscriptions
  	create_table :subscriptions do |t|
      t.string :email
      t.string :user_name
      t.text :password
      t.text :password_confirmation
      t.decimal :amount, :precision => 8, :scale => 2, :default => '0'
      t.string :stripe_customer_token
      t.string :status
      t.integer :tenant_id

      t.timestamps
    end
  end
end
