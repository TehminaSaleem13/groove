class CreateSubscriptions < ActiveRecord::Migration
  def change
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
