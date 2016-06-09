MWS::Connection.class_eval do
 
  def public_attrs
    [:aws_access_key_id, :seller_id, :marketplace_id, :host, :MWS_auth_token]
  end

end
Mws::Connection.class_eval do
    attr_reader :merchant, :orders, :products, :feeds, :log
    def initialize(overrides)
      @log = Logging.logger[self]
      @scheme = overrides[:scheme] || 'https'
      @host = overrides[:host] || 'mws.amazonservices.com'
      @merchant = overrides[:merchant]
      raise Mws::Errors::ValidationError, 'A merchant identifier must be specified.' if @merchant.nil?
      @access = overrides[:access]
      raise Mws::Errors::ValidationError, 'An access key must be specified.' if @access.nil?
      @secret = overrides[:secret]
      @MWS_auth_token = overrides[:MWS_auth_token]
      @marketplace_id = overrides[:marketplace_id]
      raise Mws::Errors::ValidationError, 'A secret key must be specified.' if @secret.nil?
      @orders = Mws::Apis::Orders.new self
      @products = Mws::Apis::Products.new self
      @feeds = Mws::Apis::Feeds::Api.new self
    end
    private
        def request(method, path, params, body, overrides)
          overrides[:xpath] ||= params.delete(:xpath)
          query =  Mws::Query.new({
             action: overrides[:action],
             version: overrides[:version],
             merchant: @merchant,
             access: @access,
             m_w_s_auth_token: @MWS_auth_token,
             marketplace_id: @marketplace_id
           }.merge(params))
         signer =  Mws::Signer.new method: method, host: @host, path: path, secret: @secret
         parse response_for(method, path, signer.sign(query), body), overrides
        end

    end