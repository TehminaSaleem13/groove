# frozen_string_literal: true

class ShipworksCredential < ActiveRecord::Base
  # attr_accessible :auth_token, :store_id

  validates_presence_of :auth_token
  validates_presence_of :store_id

  validates_uniqueness_of :auth_token

  # attr_accessible :auth_token, :store, :shall_import_in_process,
  #                 :shall_import_new_order, :shall_import_not_shipped, :shall_import_shipped,
  #                 :shall_import_no_status, :import_store_order_number, :shall_import_ignore_local, :gen_barcode_from_sku

  belongs_to :store

  def can_import_an_order?
    shall_import_in_process || shall_import_new_order || shall_import_not_shipped ||
      shall_import_shipped || shall_import_no_status || shall_import_ignore_local
  end
end
