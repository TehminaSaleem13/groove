# frozen_string_literal: true

class PackingCamController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :set_order, only: :show
  before_action :load_data, only: :show

  def show
    result = { status: true }
    if @order
      box_data = @order.get_boxes_data
      boxinfo = {}
      boxinfo['items'] = []
      boxinfo['boxes'] = box_data[:box]
      boxinfo['order_item_boxes'] = box_data[:order_item_boxes]
      boxinfo['list'] = box_data[:list]
      @order.order_items.includes(
        product: %i[
          product_inventory_warehousess
          product_skus product_cats product_barcodes
          product_images
        ]
      ).each do |orderitem|
        boxinfo['items'].push(retrieve_order_item(orderitem))
      end
      result.merge!(setting: @scan_pack_setting, order: @order, packing_cams: @order.packing_cams, order_items: @order.order_items, boxinfo: boxinfo)
      result[:order_activities] = @order.order_activities if @scan_pack_setting.scanning_log
    else
      result[:status] = false
    end
    render json: result
  end

  private

  def load_data
    @scan_pack_setting = ScanPackSetting.first
  end

  def set_order
    @order = Order.includes(:order_items, :order_activities, :packing_cams).find_by(email: params[:email], increment_id: params[:order_number])
  end

  def retrieve_order_item(orderitem)
    orderitem_attributes = orderitem.attributes
    orderitem_attributes['qty'] = orderitem.qty + orderitem.skipped_qty
    order_item = { 'iteminfo' => orderitem_attributes }
    product = orderitem.product
    if product.nil?
      order_item['productinfo'] = nil
      order_item['productimages'] = nil
    else
      product_attrs = init_product_attrs(product)
      order_item = order_item.merge(product_attrs)
    end
    order_item
  end

  def init_product_attrs(product)
    location_primary = begin
                         product.try(:primary_warehouse).location_primary
                       rescue StandardError
                         ''
                       end
    order_item = { 'productinfo' => product,
                   'available_inv' => order_item_available_inv(product),
                   'sku' => product.primary_sku,
                   'barcode' => product.primary_barcode,
                   'category' => product.primary_category,
                   'image' => product.base_product.primary_image,
                   'packing_instructions' => product.packing_instructions,
                   'qty_on_hand' => product.try(:primary_warehouse).try(:quantity_on_hand),
                   'location_primary' => location_primary }
  end

  def order_item_available_inv(product)
    available_inv = 0
    inv_warehouses = product.product_inventory_warehousess
    inv_warehouses.each { |iwh| available_inv += iwh.available_inv.to_i }
    available_inv
  end
end
