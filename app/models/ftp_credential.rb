# frozen_string_literal: true

class FtpCredential < ApplicationRecord
  # attr_accessible :host, :port, :username, :use_ftp_import, :store_id, :password, :connection_method, :connection_established, :use_ftp_import, :product_ftp_host, :product_ftp_username, :product_ftp_password, :product_ftp_connection_method, :product_ftp_connection_established, :use_product_ftp_import
  # validates_presence_of :host, :username, :password

  belongs_to :store
end
