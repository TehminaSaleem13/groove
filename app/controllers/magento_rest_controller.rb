class MagentoRestController < ApplicationController
  before_filter :groovepacker_authorize!, :except => [:callback, :success]
  before_filter :initialize_response_hash
  before_filter :find_store_credential, :only => [:magento_authorize_url, :get_access_token, :disconnect]
  include Groovepacker::MagentoRest::MagentoRestCommon

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

  def check_connection
    store = Store.find_by_id(params[:store_id])
    magento_rest_service = MagentoRest::MagentoRestService.new(store: store)
    response = magento_rest_service.check_connection
    
    render json: response
  end

  def callback
    begin
      @credential = MagentoRestCredential.find_by_store_token(params[:store_token])
      @consumer_key = params[:oauth_consumer_key]
      @consumer_secret = params[:oauth_consumer_secret]
      @oauth_verifier = params[:oauth_verifier]
      @store_base_url = params[:store_base_url]
      @oauth_token_secret = ''
      @oauth_token = nil
      fetch_request_token
      fetch_oauth_token_secret_and_access_token
      
      render json: {status: 200, massage: "Authenticated Successfully"}
    rescue Exception => ex
      render json: {status: 400, massage: "Sorry, something went wrong"}
    end
  end

  def success
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

    def fetch(method, uri, params, filters_or_data={})
      signature_base_string = signature_base_string(method, uri, params)
      params['oauth_signature'] = url_encode(sign(signing_key, signature_base_string))
      header_string = header(params)
      response = request_update_data(header_string, uri, method)
    end

    def fetch_request_token
      response = fetch("POST", "#{@store_base_url}oauth/token/request", parameters)
      tokens_hash = get_tokens_from_response(response)
      @oauth_token = tokens_hash["oauth_token"]
      @oauth_token_secret = tokens_hash["oauth_token_secret"]
    end

    def fetch_oauth_token_secret_and_access_token
      resp = fetch("POST", "#{@store_base_url}oauth/token/access", parameters)
      permanent_tokens = get_tokens_from_response(resp)
      @credential.api_key = @consumer_key
      @credential.api_secret = @consumer_secret
      @credential.access_token = permanent_tokens["oauth_token"]
      @credential.oauth_token_secret = permanent_tokens["oauth_token_secret"]
      @credential.save
    end

    def get_tokens_from_response(response)
      tokens_hash = {}
      tokens = response.split('&')
      tokens.each {|token_string| tokens_hash[token_string.split("=").first] = token_string.split("=").last  }
      return tokens_hash
    end
end
