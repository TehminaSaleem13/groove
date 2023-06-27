# frozen_string_literal: true

class PrintController < ApplicationController
  skip_before_action :verify_authenticity_token

  QZ_CERTIFICATE_PATH = Rails.root.join('config', 'qz_license', 'digital-certificate.txt')
  QZ_PRIVATE_KEY_PATH = Rails.root.join('config', 'qz_license', 'qz-private-key.pem')

  def qz_certificate
    certificate = File.read(QZ_CERTIFICATE_PATH)
    raise unless File.exist?(QZ_CERTIFICATE_PATH)

    render plain: certificate
  rescue StandardError
    head :service_unavailable
  end

  def qz_sign
    digest = OpenSSL::Digest.new('sha512')
    raise unless File.exist?(QZ_PRIVATE_KEY_PATH)

    file_content = begin
                     File.read(QZ_PRIVATE_KEY_PATH)
                   rescue StandardError
                     ''
                   end
    pkey = OpenSSL::PKey.read(file_content)
    signed = pkey.sign(digest, params[:request])
    encoded = Base64.encode64(signed)

    render plain: encoded
  rescue StandardError
    head :service_unavailable
  end
end
