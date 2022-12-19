# frozen_string_literal: true

module FTP
  class FTPBase
    attr_accessor :directory, :host, :connection_method, :username, :password
    def initialize(store, type)
      self.store = store
      credential = store.ftp_credential
      set_connection_values(credential, type) unless credential.nil?
    end

    def set_connection_values(credential, type)
      val = type == 'product' ? 'product_ftp_' : ''
      self.connection_method = credential.send(val + 'connection_method')
      self.username = credential.send(val + 'username')
      self.password = credential.send(val + 'password')
      split_location = credential.send(val + 'host').split('/')
      self.host = split_location.first
      split_location.shift
      self.directory = begin
                         split_location.join('/')
                       rescue StandardError
                         ''
                       end
    end

    def connect; end

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
end
