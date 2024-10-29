# frozen_string_literal: true

class OrderSerial < ApplicationRecord
  belongs_to :order
  belongs_to :product
  # attr_accessible :serial, :order_id, :product_id, :second_serial
  has_many :order_item_order_serial_product_lots
  #===========================================================================================
  # please update the delete_orders library if adding before_destroy or after_destroy callback
  # or adding dependent destroy for associated models
  #===========================================================================================
  DATE_FORMAT = '%y%m%d'

  def create_update_gs_barcode_data(gs_data, order_serial)
    update_attributes = {}

    update_attributes[:mfg_date] = DateTime.strptime(gs_data[:gs_mfg_date], DATE_FORMAT)rescue nil if gs_data[:gs_mfg_date]
    update_attributes[:bestbuy_date] = DateTime.strptime(gs_data[:gs_bestbuy_date], DATE_FORMAT)rescue nil if gs_data[:gs_bestbuy_date]
    update_attributes[:exp_date] = DateTime.strptime(gs_data[:gs_exp_date], DATE_FORMAT)rescue nil if gs_data[:gs_exp_date]
    update_attributes[:lot] = gs_data[:gs_batch_lot_number] if gs_data[:gs_batch_lot_number]
    update_attributes[:serial] = gs_data[:gs_serial_number] if gs_data[:gs_serial_number]

    order_serial.update(update_attributes) unless update_attributes.empty?
  end
end
