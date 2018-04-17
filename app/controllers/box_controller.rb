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
      unless params[:kit_product_id].blank?
        kit = OrderItemKitProduct.find_by_id(params[:kit_product_id])
        if kit
          order_item.scanned_qty = 0
          order_item.clicked_qty = order_item.clicked_qty - kit.clicked_qty
          order_item.scanned_status = 'partially_scanned'
          if order_item.order_item_kit_products.map(&:scanned_qty).sum == 0          
            order_item.scanned_status = "notscanned" 
            order_item.box_id = nil
          end
          order_item.save

          kit.scanned_qty = 0
          kit.clicked_qty = 0
          kit.scanned_status = "notscanned"
          kit.save
        end
      else
        order_item.scanned_qty = 0
        order_item.clicked_qty = 0
        order_item.scanned_status = "notscanned"
        order_item.box_id = nil
        order_item.save
      end
      unscanned_items = order_item.order.get_unscanned_items
      scanned_items = order_item.order.get_scanned_items
      scanning_count = order_item.order.scanning_count
      return render json: { scanned_items: scanned_items, unscanned_items: unscanned_items, scanning_count: scanning_count, status: true }
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
end
