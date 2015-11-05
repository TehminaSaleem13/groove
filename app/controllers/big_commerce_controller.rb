class BigCommerceController < ApplicationController
  before_filter :groovepacker_authorize!, :only => [:check_connection, :disconnect]

  def setup
  	# redirect to admin page with the big-commerce and with groove-solo plan
    # get shop name
  	@shop_name = get_shop_name(params[:shop])
    flash[:notice] = "Store Created succefully."
    #redirect_to subscriptions_path(plan_id: 'groove-solo', bigcommerce: shop_name )
  end

  def bigcommerce
    auth_hash = generate_access_token
    unless cookies[:tenant_name].blank?
      Apartment::Tenant.switch(cookies[:tenant_name])
      @bigcommerce_credentials = BigCommerceCredential.find_by_store_id(cookies[:store_id])
      @bigcommerce_credentials.access_token = auth_hash["access_token"] rescue nil
      @bigcommerce_credentials.store_hash = auth_hash["context"] rescue nil
      @bigcommerce_credentials.save
      cookies.delete(:tenant_name)
      cookies.delete(:store_id)
      redirect_to big_commerce_complete_path
    else
      cookies[:bc_auth] = {:value => auth_hash , :domain => :all}
      redirect_to big_commerce_setup_path(:shop => "#{params['context'].split("/").last}.mybigcommerce.com")
    end
  end

  def uninstall
    render json: {:status => 200}
  end

  def load
    render json: {:status => 200}
  end
  
  def remove
    render json: {:status => 200}
  end

  def check_connection
    store = Store.find_by_id(params[:store_id])
    bc_credential = BigCommerceCredential.find_by_store_id(store.try(:id))
    if bc_credential.access_token && bc_credential.access_token
      response = HTTParty.get("https://api.bigcommerce.com/#{bc_credential.store_hash}/v2/time",
                headers: {
                  "X-Auth-Token" => bc_credential.access_token,
                  "X-Auth-Client" => ENV["BC_CLIENT_ID"],
                  "Content-Type" => "application/json",
                  "Accept" => "application/json"
                }
            )
      parsed_json = JSON.parse(response) rescue response
      if parsed_json && parsed_json["error"]
        render json: {status: false, message: parsed_json["error"]}
      else
        render json: {status: true, message: "Connection tested successfully"}
      end
    else
      render json: {status: false, message: "Either accss token or store hash doesn't exist, Please go through the installation again"}
    end
  end

  def complete
  end

  def disconnect
    store = Store.find_by_id(params[:store_id])
    store_credentials = store.big_commerce_credential
    if store_credentials.update_attributes(:store_hash => nil, :access_token => nil)
      render status: 200, json: 'disconnected'
    else
      render status: 304, json: 'not disconnected'
    end
  end

  private
    def get_shop_name(shop_name)
      (shop_name.split(".").length == 3) ? shop_name.split(".").first : nil
    end

    def generate_access_token
      url = 'https://login.bigcommerce.com/oauth2/token'
      body_attrs = { client_id: ENV['BC_CLIENT_ID'], client_secret: ENV['BC_CLIENT_SECRET'], code: params[:code], scope: params[:scope], grant_type: :authorization_code, redirect_uri: "https://6cd9df50.ngrok.com/bigcommerce/callback", context: params[:context] }
      response = HTTParty.post('https://login.bigcommerce.com/oauth2/token', body: body_attrs.to_json, headers: { "X-Auth-Client" => ENV['BC_CLIENT_ID'], "Content-Type" => "application/json", "Accept" => "application/json" })
      return response
    end
end
