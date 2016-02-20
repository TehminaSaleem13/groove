module Connection

  def check_connection_for_csv_import(mapping, store, import_item)
    status = true
    unless !mapping.nil? && !mapping.order_csv_map.nil? && store.ftp_credential.username && store.ftp_credential.password && store.ftp_credential.host
      import_item.update_attributes( status: 'failed', message: "connection not established or no maps selected for the csv store" )
      status = false
    end
    return status
  end

  def check_connection_for_shopify_or_bc(store, store_type, import_item)
    connection_status = true
    case store_type
    when "BigCommerce"
      connection_status = check_bc_connection(store, import_item)
    when "Shopify"
      connection_status = check_shopify_connection(store, import_item)
    end
    return connection_status
  end

  def check_bc_connection(store, import_item)
    bc_service = BigCommerce::BigCommerceService.new(store: store)
    connection_response = bc_service.check_connection
    return true if connection_response && connection_response[:status]
    import_item.update_attributes(status: 'failed', message: "Open store settings to authorize connection.")
    return false
  end

  def check_shopify_connection(store, import_item)
    shopify_credential = ShopifyCredential.where(:store_id => store.id).first
    return true if shopify_credential.access_token
    import_item.update_attributes(status: 'failed', message: 'Not yet connected - Please click the Shopify icon and connect to your store')
    return false
  end
  
end
