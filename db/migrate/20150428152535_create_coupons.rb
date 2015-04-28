class CreateCoupons < ActiveRecord::Migration
  def change
    create_table :coupons do |t|
    	t.string :coupon_id, :null=>false
    	t.integer :percent_off
    	t.decimal :amount_off
    	t.string :duration
    	t.date :redeem_by
    	t.integer :max_redemptions
    	t.integer :times_redeemed
    	t.boolean :is_valid, :null=>false

      t.timestamps
    end
  end
end
