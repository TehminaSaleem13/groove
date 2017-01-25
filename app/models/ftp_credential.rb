class FtpCredential < ActiveRecord::Base
  attr_accessible :host, :port, :username, :use_ftp_import, :store_id, :password, :connection_method, :connection_established, :use_ftp_import
  # validates_presence_of :host, :username, :password

  belongs_to :store
end
