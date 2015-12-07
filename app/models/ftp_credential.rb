class FtpCredential < ActiveRecord::Base
  attr_accessible :host, :port, :username, :use_ftp_import, :store_id
  # validates_presence_of :host, :username, :password

  belongs_to :store
end
