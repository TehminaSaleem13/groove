class AddCouponIdToSubscriptions < ActiveRecord::Migration[5.1]
  def change
    add_column :subscriptions, :coupon_id, :string
  end
end
