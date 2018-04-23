class BoxController < ApplicationController
  before_filter :groovepacker_authorize!

  def create
    box = Box.new(name: params[:name], order_id: params[:order_id])
    if box.save
      return render json: box.as_json(only: [:id, :name])
    end
    render json:  { status: false } 
  end

  def remove_from_box
    order_item = OrderItem.find_by_id(params["order_item_id"])
    if order_item
      @order = order_item.order
      unless params[:kit_product_id].blank?
        reset_individual_order_item(order_item)
      else
        reset_single_order_item(order_item)
      end
      @result = Hash.new 
      @result[:unscanned_items] = @order.get_unscanned_items
      @result[:scanned_items] = @order.get_scanned_items
      @result[:scanning_count] = @order.scanning_count
      boxes_data = @order.get_boxes_data
      @result[:box] = boxes_data[:box]
      @result[:order_item_boxes] = boxes_data[:order_item_boxes]
      @result[:status] = true
      return render json: @result
    end
    render json: { status: false }
  end

  def remove_empty
    boxes = Box.where(id: params[:ids])
    if boxes.destroy_all
      return render json:  { status: true }
    end
    render json:  { status: false }
  end

  private
  def addactivity order_item, box
    order_item.order.addactivity("Item with SKU: " + order_item.product.primary_sku + " has been removed from #{box.name}", current_user.username)
  end

  def reset_single_order_item order_item
    order_item_box = OrderItemBox.where(order_item_id: order_item.id, box_id: params[:box_id]).first
    order_item.scanned_qty = order_item.scanned_qty - order_item_box.item_qty
    if order_item.scanned_qty == 0
      order_item.reset_scanned
    else
      order_item.scanned_status = "partially_scanned"
      order_item.clicked_qty = order_item.clicked_qty - order_item_box.item_qty
    end
    if order_item.save
      addactivity(order_item, order_item_box.box)
      order_item_box.destroy
    end
  end

  def reset_individual_order_item order_item
    kit = OrderItemKitProduct.find_by_id(params[:kit_product_id])
    if kit
      order_item_box = OrderItemBox.where(order_item_id: order_item.id, box_id: params[:box_id], kit_id: kit.id).first
      reset_kit(kit, order_item_box)

      if order_item.scanned_qty != 0
        order_item.scanned_qty = order_item.scanned_qty - order_item_box.item_qty
        order_item.clicked_qty = order_item.clicked_qty - order_item_box.item_qty
        order_item.scanned_status = 'partially_scanned'
      end

      if order_item.order_item_kit_products.map(&:scanned_qty).sum == 0
        order_item.reset_scanned
        addactivity(order_item, order_item_box.box) if order_item.save
      else
        order_item.save
      end

      order_item_box.destroy
    end
  end

  def reset_kit kit, order_item_box 
    kit.scanned_qty = kit.scanned_qty - order_item_box.item_qty
    if kit.scanned_qty == 0
      kit.clicked_qty = 0
      kit.scanned_status = "notscanned"
    else
      kit.clicked_qty = kit.clicked_qty - order_item_box.item_qty
      kit.scanned_status = "partially_scanned"
    end

    if kit.save
      kit.order_item.order.addactivity(
        "Kit Part item with SKU: " + kit.cached_product_kit_skus.cached_option_product.cached_primary_sku + " has been removed from #{order_item_box.box.name}",
        current_user.username
      )
    end
  end
end
