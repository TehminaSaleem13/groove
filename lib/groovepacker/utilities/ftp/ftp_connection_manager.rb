module FTP
	class FtpConnectionManager
		def self.get_instance(store)
			if store.ftp_credential.connection_method == 'ftp'
	      return FTP.new(store)
	    elsif store.ftp_credential.connection_method == 'sftp'
	      return SFTP.new(store)
	    end
		end
	end
end
