# frozen_string_literal: true

module FTP
  class FtpConnectionManager
    def self.get_instance(store, type = nil)
      if type == 'product'
        if store.ftp_credential.product_ftp_connection_method == 'ftp'
          FTP.new(store, type)
        elsif store.ftp_credential.product_ftp_connection_method == 'sftp'
          SFTP.new(store, type)
        end
      else
        if store.ftp_credential.connection_method == 'ftp'
          FTP.new(store, type)
        elsif store.ftp_credential.connection_method == 'sftp'
          SFTP.new(store, type)
        end
      end
    end
  end
end
