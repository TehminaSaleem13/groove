class ShopifyController < ApplicationController
  before_filter :authenticate_user!, :except => [:auth, :callback]

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

  #hmac=d43d3f1d1ef5453bcdc62909e8db267ca95dc524dd3c61871c051abd338606a1&
  #shop=groovepacker-dev-shop.myshopify.com&
  #signature=9496a95477ede166870e8f08da1b4526&
  #timestamp=1430733874
  def callback
    # redirect to admin page with the shopify and with groove-solo plan
    # get shop name
    shop_name = get_shop_name(params[:shop])
    redirect_to subscriptions_path(plan_id: 'groove-solo', shopify: shop_name )
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

  private

  def get_shop_name(shop_name)
    (shop_name.split(".").length == 3) ? shop_name.split(".").first : nil
  end
end