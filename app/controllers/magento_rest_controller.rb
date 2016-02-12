class MagentoRestController < ApplicationController
  before_filter :groovepacker_authorize!
  before_filter :initialize_response_hash
  before_filter :find_store_credential, :only => [:magento_authorize_url, :get_access_token, :disconnect]

  def magento_authorize_url
    if @credential
      initialize_magento_oauth
      @result = @oauth.generate_authorize_url(@result)
      render json: @result
    else
      @result['status'] = false
      @result['message'] = 'Something went wrong'
      render json: @result
    end
  end

  def get_access_token
    if @credential
      initialize_magento_oauth
      @result = @oauth.generate_access_token(@credential, @result)
      render json: @result
    else
      @result['status'] = false
      @result['message'] = 'Something went wrong'
      render json: @result
    end
  end

  def disconnect
    @credential.update_attributes(:access_token => nil)
    render json: @result
  end
  
  private
    def initialize_response_hash
      @result = {}
      @result['status'] = true
      @result['message'] = ''
    end

    def find_store_credential
      store = Store.find_by_id(params[:store_id])
      @credential = store.magento_rest_credential rescue nil
    end

    def initialize_magento_oauth
      @oauth ||= Groovepacker::MagentoOauth.new(:host => @credential.host, :store_admin_url => @credential.store_admin_url, :api_key => @credential.api_key, :api_secret => @credential.api_secret, :oauth_varifier => params[:oauth_varifier] )
    end
end
