# frozen_string_literal: true

class LeaderBoard < ApplicationRecord
  # attr_accessible :order_id, :order_item_count, :scan_time
  belongs_to :order
end
