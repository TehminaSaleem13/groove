MWS::Connection.class_eval do
 
  def public_attrs
    [:aws_access_key_id, :seller_id, :marketplace_id, :host, :MWS_auth_token]
  end
 
end
