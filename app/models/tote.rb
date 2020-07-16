class Tote < ActiveRecord::Base
  attr_accessible :name, :order_id, :number, :pending_order_id

  belongs_to :order
  belongs_to :tote_set
  validates :name, presence: true, uniqueness: true
end
