class Tote < ActiveRecord::Base
  # attr_accessible :name, :order_id, :number, :pending_order

  belongs_to :order
  belongs_to :tote_set
  validates :name, presence: true, uniqueness: true

  def reset_pending_order
    update(pending_order: false)
  end

  def release_order
    update(order_id: nil, pending_order: false)
  end
end
