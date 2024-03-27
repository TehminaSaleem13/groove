# frozen_string_literal: true

class HmacEncryptor
  def initialize(secret_key, data)
    @secret_key = secret_key
    @data = data
  end

  def generate_signature
    digest = OpenSSL::Digest.new('sha256')
    OpenSSL::HMAC.hexdigest(digest, @secret_key, @data)
  end
end
