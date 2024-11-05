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
    update_attributes = {
      mfg_date: parse_date(gs_data[:gs_mfg_date]),
      bestbuy_date: parse_date(gs_data[:gs_bestbuy_date]),
      exp_date: parse_date(gs_data[:gs_exp_date]),
      lot: gs_data[:gs_batch_lot_number],
      serial: gs_data[:gs_serial_number]
    }.compact

    order_serial.update(update_attributes) if update_attributes.present?
  end

  def parse_date(date_string)
    DateTime.strptime(date_string, DATE_FORMAT) rescue nil if date_string
  end
end
