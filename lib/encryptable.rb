# frozen_string_literal: true

module Encryptable
  require 'openssl'
  require 'zlib'
  require 'base64'

  # Define a constant key (32 bytes for AES-256)
  # OpenSSL::Random.random_bytes(32)
  AES_KEY = "\xFF$\r\xE5A\xAB?\xDB\xD2\x9Eg\xE7\xF0\xBB\xE4\xD6O\x85\xBF|\xC2\xABBH\xA95\xD3\xA6\x1E\xB0\xA2\xBE"

  # Compress the payload using Zlib
  def compress_data(data)
    Zlib::Deflate.deflate(data)
  end

  # Decompress the data using Zlib
  def decompress_data(data)
    Zlib::Inflate.inflate(data)
  end

  # Encrypt the payload using AES-256-CBC with a constant key
  def encrypt_data(data)
    cipher = OpenSSL::Cipher.new('aes-256-cbc')
    cipher.encrypt
    cipher.key = AES_KEY
    iv = cipher.random_iv
    encrypted = cipher.update(data) + cipher.final
    # Encode the IV and encrypted data as Base64
    Base64.encode64(iv + encrypted)
  end

  # Decrypt the payload using AES-256-CBC with a constant key
  def decrypt_data(data)
    decipher = OpenSSL::Cipher.new('aes-256-cbc')
    decoded_data = Base64.decode64(data)
    iv = decoded_data[0..15] # First 16 bytes are the IV
    encrypted_data = decoded_data[16..] # The rest is the encrypted data

    decipher.decrypt
    decipher.key = AES_KEY
    decipher.iv = iv
    decipher.update(encrypted_data) + decipher.final
  end

  # Full process: Compress + Encrypt
  def compress_and_encrypt(payload)
    compressed_data = compress_data(payload)
    encrypt_data(compressed_data)
  end

  # Full process: Decrypt + Decompress
  def decrypt_and_decompress(encrypted_data)
    decrypted_data = decrypt_data(encrypted_data)
    decompress_data(decrypted_data)
  end
end
