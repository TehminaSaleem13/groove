class FtpCredential < ActiveRecord::Base
  attr_accessible :host, :port, :username
  validates_presence_of :host, :username, :password

  belongs_to :store
end
