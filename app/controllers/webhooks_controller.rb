# frozen_string_literal: true

class WebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token

  # before_action :verify_webhook, except: %i[delete_customer delete_shop show_customer]

  def delete_customer
    head :ok
  end

  def delete_shop
    head :ok
  end

  def show_customer
    head :ok
  end

  private

  def verify_webhook
    data = request.body.read
    hmac_header = request.headers['X-Shopify-Hmac-SHA256']
    digest = OpenSSL::Digest.new('sha256')
    calculated_hmac = Base64.strict_encode64(OpenSSL::HMAC.digest(digest, ENV['SHOPIFY_SHARED_SECRET'], data))

    head :unauthorized unless ActiveSupport::SecurityUtils.secure_compare(calculated_hmac, hmac_header)
    request.body.rewind
  end

end
