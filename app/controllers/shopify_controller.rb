class ShopifyController < ApplicationController
  before_filter :authenticate_user!, :except => [:auth]

  # {
  #  "code"=>"58a883f4bb36e4e953431549abff383c", 
  #  "hmac"=>"0542bc2a50645289f1af07d4f85f3ebe9883af6ab402ea24f2c1c1bbac57f8c8", 
  #  "shop"=>"groovepacker-dev-shop.myshopify.com", 
  #  "signature"=>"1a90fbf68c06ba55d8d7f6a7740e4a79", 
  #  "timestamp"=>"1428928120", 
  #  "id"=>"1" 
  # }
  def auth
    store = Store.find(params[:id])
    @shopify_credential = store.shopify_credential
    session = ShopifyAPI::Session.new(@shopify_credential.shop_name + ".myshopify.com")
    @result = false
    
    begin
      @result = true if @shopify_credential.update_attributes({ 
          access_token: session.request_token(params.except(:id))
        })
    rescue Exception => ex
      @result = false
    end
  end

  def disconnect
    store = Store.find(params[:id])
    @shopify_credential = store.shopify_credential
    session = ShopifyAPI::Session.new(@shopify_credential.shop_name + ".myshopify.com")
    if @shopify_credential.update_attributes({ 
        access_token: nil
      })
      render status: 200, json: 'disconnected'
    else
      render status: 304, json:'not disconnected'
    end
  end
end