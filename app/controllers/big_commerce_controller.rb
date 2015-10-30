class BigCommerceController < Devise::OmniauthCallbacksController
  before_filter :groovepacker_authorize!, :except => [:bigcommerce, :complete]

  def setup
  	# redirect to admin page with the big-commerce and with groove-solo plan
    # get shop name
  	@shop_name = get_shop_name(params[:shop])
    flash[:notice] = "Store Created succefully."
    #redirect_to subscriptions_path(plan_id: 'groove-solo', bigcommerce: shop_name )
  end

  def bigcommerce
    unless cookies[:tenant_name].blank?
	  auth = request.env["omniauth.auth"]
	  Apartment::Tenant.switch(cookies[:tenant_name])
	  @bigcommerce_credentials = BigCommerceCredential.find_by_store_id(cookies[:store_id])
	  @bigcommerce_credentials.access_token = auth['credentials']['token'].token rescue nil
	  @bigcommerce_credentials.store_hash = auth['extra']['context'] rescue nil
	  @bigcommerce_credentials.save
	  cookies.delete(:tenant_name)
	  cookies.delete(:store_id)
	  redirect_to big_commerce_complete_path
	else
      cookies[:bc_auth] = {:value => auth , :domain => :all}
	  redirect_to big_commerce_setup_path(:shop => "#{auth['extra']['context'].split("/").last}.mybigcommerce.com")
	end
  end

  def complete
  end

  private
    def get_shop_name(shop_name)
      (shop_name.split(".").length == 3) ? shop_name.split(".").first : nil
    end
end
