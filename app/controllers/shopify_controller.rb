class ShopifyController < ApplicationController
  before_filter :authenticate_user!, :except => [:auth]

  def auth
    @stores = Store.where("store_type != 'system'")

    respond_to do |format|
      format.json { render json: @stores}
    end
  end

end