# frozen_string_literal: true

class WebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token
  # skip_before_action :groovepacker_authorize!
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

  def orders_create
    handle_and_enqueue_order_import
  end

  def orders_update
    handle_and_enqueue_order_import
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

    def handle_and_enqueue_order_import
      uri =  request.headers['host']
      if uri.present?
        subdomain = uri&.split('.')[0] 
        store_name = request.headers['x-shopify-shop-domain'].split('.')[0]
        ImportOrdersJob.perform_later(store_name, subdomain, "regular", nil) if subdomain.present?
      else
        Rollbar.error(request)
      end
      render json: {success: true}.to_json
    end
  
end
