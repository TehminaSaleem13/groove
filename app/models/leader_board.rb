class LeaderBoard < ActiveRecord::Base
  attr_accessible :order_id, :order_item_count, :scan_time
  belongs_to :order
end
