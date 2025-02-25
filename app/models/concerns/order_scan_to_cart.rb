# frozen_string_literal: true

module OrderScanToCart
  extend ActiveSupport::Concern

  included do
    scope :ready_for_picking, -> {
      where(status: 'awaiting')
        .where(workflow_state: nil)
        .where(assigned_user_id: nil)
        .where('order_placed >= ?', 14.days.ago)
        .order(order_placed: :asc)
    }
  end

  def assign_to_cart(cart, tote_info)
    update(
      workflow_state: 'pick_in_progress',
      assigned_cart_tote_id: cart.id,
      assigned_tote_row: tote_info[:row_name]
    )
  end

  def mark_as_picked
    update(workflow_state: 'picked')
  end

  def mark_as_scanned
    update(workflow_state: 'scanned')
  end

  def reset_cart_assignment
    update(
      workflow_state: nil,
      assigned_cart_tote_id: nil,
      assigned_tote_row: nil
    )
  end
end