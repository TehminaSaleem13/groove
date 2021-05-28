class Tote < ActiveRecord::Base
  # attr_accessible :name, :order_id, :number, :pending_order

  belongs_to :order, optional: true
  belongs_to :tote_set, optional: true
  validates :name, presence: true, uniqueness: true
end
