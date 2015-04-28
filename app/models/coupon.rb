class Coupon < ActiveRecord::Base
  attr_accessible :coupon_id, :percent_off, :amount_off, :duration, :redeem_by, :max_redemptions, :times_redeemed, :is_valid
end
