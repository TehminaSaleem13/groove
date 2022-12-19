# frozen_string_literal: true

ShopifyAPI::Context.setup(
  api_key: ENV['SHOPIFY_API_KEY'],
  api_secret_key: ENV['SHOPIFY_SHARED_SECRET'],
  host_name: "admin.#{ENV['SITE_HOST']}",
  scope: 'read_products, write_products, read_orders, write_orders, read_all_orders, read_fulfillments, write_fulfillments',
  session_storage: ShopifyAPI::Auth::FileSessionStorage.new, # See more details below
  is_embedded: false, # Set to true if you are building an embedded app
  is_private: false, # Set to true if you are building a private app
  api_version: '2021-10' # The version of the API you would like to use
)
