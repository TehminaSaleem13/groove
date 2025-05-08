class CartTote < ApplicationRecord
  belongs_to :cart_row

  validates :tote_id, presence: true
  validates :width, :height, :length, presence: true

  attribute :width, :float, default: 0.0
  attribute :height, :float, default: 0.0
  attribute :length, :float, default: 0.0

  def get_dimension_unit
    GeneralSetting.setting.product_dimension_unit # Assuming this returns 'inches' or 'centimeters'
  end

  def convert_dimensions(value, from_unit, to_unit)
    if from_unit == 'inches' && to_unit == 'centimeters'
      value * 2.54
    elsif from_unit == 'centimeters' && to_unit == 'inches'
      value / 2.54
    else
      value
    end
  end

  def tote_volume
    width * height * length
  end

  def assign_order(order)
    order_volume = order.total_order_volume
    if order_volume <= tote_volume
      # Assign the order to the tote
      remaining_volume = tote_volume - order_volume
      if remaining_volume >= 0
        # Assign the order to the current tote
        order.update(assigned_cart_tote_id: tote_id)
      else
        # Assign the remaining order items to the next tote
        assign_remaining_order_items(order, remaining_volume)
      end
    else
      # Use assign_each_product method to distribute order items across multiple totes
      assign_each_product(order)
    end
  end

  def assign_remaining_order_items(order, remaining_volume)
    # Find the next available tote
    next_tote = find_next_available_tote

    if next_tote
      # Assign the remaining order items to the next tote
      order.update(assigned_cart_tote_id: next_tote.tote_id)
      next_tote.assign_order(order)
    else
      # Handle the case when there is no next tote available
      handle_order_does_not_fit(order)
    end
  end

  def assign_each_product(order)
    # Get the order items of the order
    order_items = order.order_items

    # Iterate through the order items and assign them to the tote
    order_items.each do |order_item|
      order_item_volume = order_item.order_item_volume
      if order_item_volume <= tote_volume
        # Assign the order item to the current tote
        order_item.update(assigned_cart_tote_id: tote_id)
        remaining_volume = tote_volume - order_item_volume
        if remaining_volume < 0
          # Move to the next tote
          next_tote = find_next_available_tote
          if next_tote
            order_item.update(assigned_cart_tote_id: next_tote.tote_id)
            next_tote.assign_order(order)
          else
            handle_order_does_not_fit(order)
          end
        end
      else
        # Handle the case when the order item does not fit in the tote
        handle_order_does_not_fit(order)
      end
    end
  end

  def find_next_available_tote
    # Get the remaining volume of the order items
    remaining_volume = calculate_remaining_order_volume

    # Iterate through the available totes in the cart
    @cart.cart_rows.each do |row|
      row.cart_totes.each do |tote|
        # Check if the remaining volume of the order items can fit into the tote
        if remaining_volume <= tote.tote_volume
          return tote
        end
      end
    end

    # Return nil if no suitable tote is found
    nil
  end

  def calculate_remaining_order_volume
    # Calculate the remaining volume of the order items
    # For example, you can sum the volume of the remaining order items
    remaining_order_items = get_remaining_order_items
    remaining_order_items.sum { |order_item| order_item.order_item_volume }
  end

  def get_remaining_order_items
    # Implement the logic to get the remaining order items
    # For example, you can filter the order items that have not been assigned to a tote yet
    order.order_items.select { |order_item| order_item.assigned_cart_tote_id.nil? }
  end

  def handle_order_does_not_fit(order)
    # Discard the entire order
    order.order_items.each do |order_item|
      order_item.update(product_id: nil)
    end

    # Keep track of that order with a message indicating that the order cannot fit in any tote
    puts "Order #{order.id} cannot fit in any tote"
  end
end
