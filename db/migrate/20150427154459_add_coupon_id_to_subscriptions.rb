class AddCouponIdToSubscriptions < ActiveRecord::Migration
  def change
    add_column :subscriptions, :coupon_id, :string
  end
end
