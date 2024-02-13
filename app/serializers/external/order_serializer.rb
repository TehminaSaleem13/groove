# frozen_string_literal: true

class External::OrderSerializer < ActiveModel::Serializer
  attributes :order_date, :order_number, :order_status, :store_name, :packing_user_name, :scanned_date, :warehouse_name,
             :custom_order_1, :custom_order_2, :customer_name, :address_1, :address_2, :city, :state, :zip, :tracking_num, :incorrect_scans,
             :clicked_scanned_qty, :order_items

  def order_date
    object.order_placed_time
  end

  def order_number
    object.increment_id
  end

  def order_status
    object.status
  end

  def store_name
    store&.display_origin_store_name ? object.origin_store&.store_name : store&.name
  end

  def packing_user_name
    object.packing_user&.username
  end

  def scanned_date
    object.scanned_on&.strftime('%Y-%m-%d %I:%M:%S %p')
  end

  def warehouse_name
    store&.inventory_warehouse&.name
  end

  def custom_order_1
    general_setting.custom_field_one
  end

  def custom_order_2
    general_setting.custom_field_two
  end

  def customer_name
    object.firstname.to_s + object.lastname.to_s
  end

  def zip
    object.postcode
  end

  def incorrect_scans
    object.inaccurate_scan_count
  end

  def order_items
    object.order_items.collect do |order_item|
      product = order_item.product
      product_hash = {
        barcode: product.primary_barcode,
        primary_sku: order_item.sku,
        product_name: product.name,
        ordered_qty: order_item.qty,
        item_sale_price: order_item.price,
        clicked_scanned_qty: order_item.clicked_qty,
        box_number: order_item.boxes.last&.name&.split(' ')&.last,
        scanned_count: order_item.scanned_qty,
        unscanned_count: order_item.qty - order_item.scanned_qty,
        removed_count: order_item.removed_qty,
        added_count: order_item.added_count
      }
      product_hash[:order_item_kit_products] = order_item_kit_products(order_item) if product.is_kit == 1
      product_hash
    end
  end

  private

  def store
    object.store
  end

  def general_setting
    @general_setting ||= GeneralSetting.first
  end

  def order_item_kit_products(order_item)
    order_item.order_item_kit_products.collect do |kit_item|
      product_kit_sku = kit_item.product_kit_skus
      option_product = product_kit_sku.option_product
      {
        kit_name: option_product.name,
        primary_sku: option_product.primary_sku,
        barcode: option_product.primary_barcode,
        scanned_count: kit_item.scanned_qty,
        ordered_qty: product_kit_sku.qty,
        unscanned_count: product_kit_sku.qty.to_i - kit_item.scanned_qty.to_i,
        clicked_scanned_qty: kit_item.clicked_qty
      }
    end
  end
end
