class FTPBase
  attr_accessor :directory, :host, :connection_method, :username, :password
  def initialize(store)
    self.store = store
    set_attributes
  end

  def set_attributes
    credential = store.ftp_credential
    unless credential.nil?
      self.connection_method = credential.connection_method
      self.username = credential.username
      self.password = credential.password
      split_location = credential.host.split('/')
      self.host = split_location.first
      self.directory = split_location.last
    end
  end

  def connect
    
  end

  def disconnect
    
  end

  def build_result
    {
      error_messages: [],
      success_messages: [],
      connection_obj: [],
      status: true
    }
  end

  protected
    attr_accessor :store
end
