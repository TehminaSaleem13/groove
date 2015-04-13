ShopifyAPI::Session.setup(
  {
    :api_key => ENV['SHOPIFY_API_KEY'], 
    :secret => ENV['SHOPIFY_SHARED_SECRET']
  }
)