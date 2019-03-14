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
      arrange_box(params[:order_id])
      return render json:  { status: true }
    end
    render json:  { status: false }
  end

  def delete_box
    box = Box.where(id: params[:id]).last
    if box.present?
      order_id = box.order_id
      order = Order.where(id: order_id).last
      change_box_name =  check_sequence(box)
      
      if box.order_items.empty? && box.order_item_boxes.empty? 
        add_activity_for_delete(order,box)
        box.destroy
      else
        box.order_item_boxes.each do |order_item_box|
          order_item = OrderItem.where(id: order_item_box.order_item_id).last
          order.addactivity("order item having sku #{order_item.product.primary_sku} with qty #{order_item_box.item_qty} is removed from #{box.try(:name)} due to box delete", current_user.username )
          order_item.reset_scanned
        end  
        add_activity_for_delete(order,box) 
        box.destroy
      end
      change_sequence(change_box_name)
    end  

    if order.present? && order.status == "scanned" 
      order.update_attributes(status: "awaiting") 
    end 
    render json:  { }
  end

  private
  def addactivity order_item, box
    order_item.order.addactivity("Item with SKU: " + order_item.product.primary_sku + " has been removed from #{box.name}", current_user.username)
  end

  def reset_single_order_item order_item
    order_item_box = OrderItemBox.where(order_item_id: order_item.id, box_id: params[:box_id]).first
    order_item_box.item_qty = order_item_box.item_qty - 1
    order_item_box.save
    order_item.scanned_qty = order_item.scanned_qty - 1
    
    if order_item.scanned_qty == 0
      order_item.reset_scanned
    else
      order_item.scanned_status = "partially_scanned"
      if order_item.clicked_qty > 0
        order_item.clicked_qty = order_item.clicked_qty - 1 
      end
    end
    if order_item.save
      addactivity(order_item, order_item_box.box)
      order_item_box.destroy if order_item_box.item_qty == 0 
    end
  end

  def reset_individual_order_item order_item
    kit = OrderItemKitProduct.find_by_id(params[:kit_product_id])
    if kit
      order_item_box = OrderItemBox.where(order_item_id: order_item.id, box_id: params[:box_id], kit_id: kit.id).first
      order_item_box.item_qty = order_item_box.item_qty - 1
      order_item_box.save
      reset_kit(kit, order_item_box)

      if order_item.scanned_qty != 0
        order_item.scanned_qty = order_item.scanned_qty - 1
        order_item.clicked_qty = order_item.clicked_qty - 1
        order_item.scanned_status = 'partially_scanned'
      end

      if order_item.order_item_kit_products.map(&:scanned_qty).sum == 0
        order_item.reset_scanned
        addactivity(order_item, order_item_box.box) if order_item.save
      else
        order_item.save
      end

      order_item_box.destroy if order_item_box.item_qty == 0
    end
  end

  def reset_kit kit, order_item_box 
    kit.scanned_qty = kit.scanned_qty - 1
    if kit.scanned_qty == 0
      kit.clicked_qty = 0
      kit.scanned_status = "notscanned"
    else
      kit.clicked_qty = kit.clicked_qty - 1
      kit.scanned_status = "partially_scanned"
    end

    if kit.save
      kit.order_item.order.addactivity(
        "Kit Part item with SKU: " + kit.cached_product_kit_skus.cached_option_product.cached_primary_sku + " has been removed from #{order_item_box.box.name}",
        current_user.username
      )
    end
  end

  def check_sequence(box)
    order_id = box.order_id
    change_box_name = []
    all_boxes = Box.where(order_id: order_id ).pluck(:name)
    all_boxes.each do |all_box|
      if all_box > box.name
        change_box_name  << Box.where(order_id: order_id, name: all_box ).last.id
      end
    end 
    return  change_box_name 
  end

  def change_sequence(change_box_name)
    change_box_name.each do |id|
      box = Box.where(id: id).last
      box_name = box.name   
      new_name = box_name.gsub(box_name[4] ,(box_name[4].to_i - 1).to_s) 
      save_new_name(new_name, box)
    end   
  end


  def arrange_box(order_id)
    boxes = Box.where(order_id: order_id)
    boxes_name = boxes.map(&:name)
    boxes.each do |box|
      box_name = box.name 
      i = boxes_name.index(box_name) + 1
      new_name = box_name.gsub(box_name[4] ,i.to_s) 
      save_new_name(new_name, box)
    end
  end

  def save_new_name(new_name, box)
    box.name = new_name
    box.save
  end

  def add_activity_for_delete(order, box)
    order.addactivity("#{box.try(:name)} with #{box.order_item_boxes.count} order items is deleted.", current_user.username)
  end
end
