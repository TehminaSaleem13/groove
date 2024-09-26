# frozen_string_literal: true

Rails.application.routes.draw do
  mount LetterOpenerWeb::Engine, at: '/letter_opener' if Rails.env.development?

  # Doorkeeper
  use_doorkeeper do
    controllers tokens: 'oauth/access_tokens'
  end

  get 'subscriptions', to: 'subscriptions#new'
  get 'subscriptions_login', to: 'subscriptions#login'
  post 'subscriptions', to: 'subscriptions#new'
  post 'subscriptions_login', to: 'subscriptions#login'

  match '/delayed_job' => DelayedJobWeb, :anchor => false, via: %i[get post]

  get '/404', to: 'specials#error_404'

  get '/422', to: 'specials#error_422'

  get '/500', to: 'specials#error_500'

  devise_for :users

  get '/bigcommerce/callback' => 'big_commerce#bigcommerce'
  get '/bigcommerce/uninstall' => 'big_commerce#uninstall'
  get '/bigcommerce/load' => 'big_commerce#load'
  get '/bigcommerce/remove' => 'big_commerce#remove'
  get '/big_commerce/login' => 'big_commerce#login'
  get '/big_commerce/setup' => 'big_commerce#setup'
  get '/big_commerce/complete' => 'big_commerce#complete'
  get '/big_commerce/:store_id/check_connection' => 'big_commerce#check_connection'
  put '/big_commerce/:store_id/disconnect' => 'big_commerce#disconnect'

  get '/magento_rest/:store_id/magento_authorize_url' => 'magento_rest#magento_authorize_url'
  get '/magento_rest/:store_id/get_access_token' => 'magento_rest#get_access_token'
  get '/magento_rest/:store_id/check_connection' => 'magento_rest#check_connection'
  put '/magento_rest/:store_id/disconnect' => 'magento_rest#disconnect'
  post 'magento_rest/callback' => 'magento_rest#callback'
  get 'magento_rest/redirect' => 'magento_rest#redirect'
  get 'stores/export_active_products' => 'stores#export_active_products'
  get 'stores/bin_location_api_push' => 'stores#bin_location_api_push'
  get 'stores/bin_location_api_pull' => 'stores#bin_location_api_pull'
  get 'stores/popup_shipping_label' => 'stores#popup_shipping_label'
  get 'stores/large_popup_shipping_label' => 'stores#large_popup_shipping_label'
  get 'stores/amazon_fba' => 'stores#amazon_fba'
  get 'shipstation_rest_credentials/use_chrome_extention' => 'shipstation_rest_credentials#use_chrome_extention'
  get 'shipstation_rest_credentials/use_api_create_label' => 'shipstation_rest_credentials#use_api_create_label'
  get 'shipstation_rest_credentials/switch_back_button' => 'shipstation_rest_credentials#switch_back_button'
  get 'shipstation_rest_credentials/auto_click_create_label' => 'shipstation_rest_credentials#auto_click_create_label'
  get '/settings/print_action_barcode/:id' => 'settings#print_action_barcode'
  get '/settings/print_tote_barcodes' => 'settings#print_tote_barcodes'
  put '/order_import_summary/update_display_setting' => 'order_import_summaries#update_display_setting'
  get '/order_import_summary/update_order_import_summary' => 'order_import_summaries#update_order_import_summary'
  get 'order_import_summary/download_summary_details' => 'order_import_summaries#download_summary_details'
  get '/order_import_summary/fix_imported_at' => 'order_import_summaries#fix_imported_at'
  get '/order_import_summary/delete_import_summary' => 'order_import_summaries#delete_import_summary'
  get '/order_import_summary/get_last_modified' => 'order_import_summaries#get_last_modified'
  get '/order_import_summary/get_import_details' => 'order_import_summaries#get_import_details'
  get '/orders/run_orders_status_update' => 'orders#run_orders_status_update'
  put '/shipstation_rest_credentials/:store_id/fix_import_dates' => 'shipstation_rest_credentials#fix_import_dates'
  put '/shipstation_rest_credentials/:store_id/update_product_image' => 'shipstation_rest_credentials#update_product_image'
  post 'settings/search_by_product' => 'settings#search_by_product'
  post '/settings/fetch_and_update_time_zone' => 'settings#fetch_and_update_time_zone'
  post '/settings/update_auto_time_zone' => 'settings#update_auto_time_zone'
  get 'settings/update_stat_status' => 'settings#update_stat_status'

  get '/store_settings/handle_ebay_redirect' => 'stores#handle_ebay_redirect'
  post '/amazons/products_import' => 'amazons#products_import'
  get '/delayed_jobs' => 'delayed_jobs#index'
  post '/delayed_jobs_delete' => 'delayed_jobs#destroy'
  post '/delayed_job_reset' => 'delayed_jobs#reset'
  post '/delayed_jobs_update' => 'delayed_jobs#update'
  post '/tenants/activity_log' => 'tenants#activity_log'
  post '/tenants/activity_log_v2' => 'tenants#activity_log_v2'
  post '/tenants/get_duplicates_order_info' => 'tenants#get_duplicates_order_info'
  post '/tenants/remove_duplicates_order' => 'tenants#remove_duplicates_order'
  post '/tenants/tenant_log' => 'tenants#tenant_log'
  post '/tenants/clear_redis_method' => 'tenants#clear_redis_method'
  get '/tenants/clear_all_imports' => 'tenants#clear_all_imports'
  get '/tenants/delete_summary' => 'tenants#delete_summary'
  get '/tenants/update_import_mode' => 'tenants#update_import_mode'
  get '/tenants/update_scheduled_import_toggle' => 'tenants#update_scheduled_import_toggle'
  get '/tenants/update_groovelytic_stat' => 'tenants#update_groovelytic_stat'
  get '/tenants/update_scan_workflow' => 'tenants#update_scan_workflow'
  get '/tenants/update_store_order_respose_log' => 'tenants#update_store_order_respose_log'
  get '/tenants/update_setting' => 'tenants#update_setting'
  post 'shipstation_rest_credentials/set_label_shortcut' => 'shipstation_rest_credentials#set_label_shortcut'
  post '/shipstation_rest_credentials/set_ss_label_advanced' => 'shipstation_rest_credentials#set_ss_label_advanced'
  post 'shipstation_rest_credentials/set_carrier_visibility' => 'shipstation_rest_credentials#set_carrier_visibility'
  post 'shipstation_rest_credentials/set_rate_visibility' => 'shipstation_rest_credentials#set_rate_visibility'
  post 'shipstation_rest_credentials/set_contracted_carriers' => 'shipstation_rest_credentials#set_contracted_carriers'
  post 'shipstation_rest_credentials/set_presets' => 'shipstation_rest_credentials#set_presets'
  patch 'origin_stores/:origin_store_id', to: 'origin_stores#update', as: :update_origin_store

  # Packing Cam routes
  post 'package-details' => 'packing_cam#show'

  root to: 'home#index'

  resources :home do
    collection do
      get 'userinfo'
      get 'request_socket_notifs'
      get 'check_tenant'
      get 'import_status'
    end
  end

  resources :orders do
    collection do
      get 'search'
      get 'sorted_and_filtered_data'
      get 'check_orders_tags'
      post 'add_tags'
      post 'cancel_tagging_jobs'
      post 'remove_tags'
      get 'import_orders'
      get 'import_all'
      post 'generate_pick_list'
      post 'generate_packing_slip'
      get 'generate_all_packing_slip'
      post 'order_items_export'
      post 'cancel_packing_slip'
      post 'delete_orders'
      post 'duplicate_orders'
      post 'change_orders_status'
      post 'assign_orders_to_users'
      post 'deassign_orders_from_users'
      post 'clear_assigned_tote'
      post 'update_order_list'
      post 'save_by_passed_log'
      post 'rollback'
      post 'remove_item_from_order'
      post 'remove_item_qty_from_order'
      post 'update_item_in_order'
      post 'import_shipworks'
      get 'import'
      put 'cancel_import'
      post 'get_id'
      post 'import_xml'
      post 'bulk_import_xml'
      get 'next_split_order'
      get 'import_for_ss'
      get 'cancel_all'
      post 'create_ss_label'
      post 'get_realtime_rates'
      post 'update_ss_label_order_data'
    end
    member do
      get 'print_shipping_label'
      post 'add_item_to_order'
      post 'record_exception'
      post 'clear_exception'
      get 'importorders'
      get 'clear_order_tote'
      get 'print_activity_log'
      post 'remove_packing_cam_image'
      post 'send_packing_cam_email'
      get 'get_ss_label_data'
    end
  end

  resources :products do
    collection do
      get 'import_products'
      get 'search'
      get 'import_images'
      get 'import_product_details'
      get 'get_inventory_setting'
      post 'delete_product'
      post 'duplicate_product'
      post 'change_product_status'
      post 'generate_barcode'
      post 'generate_numeric_barcode'
      post 'scan_per_product'
      post 'generate_products_csv'
      post 'generate_broken_image'
      post 'fix_shopify_broken_images'
      post 're_associate_all_products_with_shopify'
      post 'cancel_shopify_product_imports'
      post 'update_product_list'
      post 'update_image'
      post 'update_intangibleness'
      post 'print_receiving_label'
      post 'print_product_barcode_label'
      put 'update_inventory_settings'
      put 'update_inventory_record'
      put 'remove_inventory_record'
      post 'update_inventory_option'
      post 'generate_product_inventory_report'
      post 'update_generic'
      post 'bulk_barcode_generation'
      get 'bulk_barcode_pdf'
      get 'find_inactive_product'
      get 'get_report_products'
      put 'update_inventory_report'
      put 'remove_inventory_report_products'
    end
    member do
      get 'generate_barcode_slip'
      post 'convert_and_upload_image'
      put 'adjust_available_inventory'
      post 'add_image'
      post 'set_alias'
      post 'add_product_to_kit'
      post 'remove_products_from_kit'
      put 'sync_with'
    end
  end

  resources :settings do
    collection do
      get 'get_settings'
      get 'get_setting'
      get 'get_columns_state'
      put 'update_settings'
      put 'update_email_address_for_packer_notes'
      get 'get_scan_pack_settings'
      get 'order_exceptions'
      get 'order_serials'
      get 'export_csv'
      get 'auto_complete'
      post 'restore'
      post 'save_columns_state'
      post 'cancel_bulk_action'
      post 'update_scan_pack_settings'
      post 'update_packing_cam_image'
    end
  end

  resources :stores do
    collection do
      get 'get_system'
      get 'let_store_be_created'
      get 'get_ebay_signin_url'
      get 'ebay_user_fetch_token'
      get 'csv_map_data'
      post 'delete_store'
      post 'duplicate_store'
      post 'change_store_status'
      post 'create_update_store'
      post 'update_store_list'
      get 'get_order_details'
      get 'update_store_lro'
      post 'update_shopify_token'
      post 'update_shopline_token'
      post 'fetch_label_related_data'
      post 'create_update_screct_key_ss'
    end
    member do
      get 'verify_tags'
      get 'verify_awaiting_tags'
      put 'update_all_locations'
      get 'connect_and_retrieve'
      post 'create_update_ftp_credentials'
      post 'delete_ebay_token'
      get 'update_ebay_user_token'
      post 'csv_import_data'
      post 'csv_do_import'
      post 'csv_check_data'
      post 'csv_product_import_cancel'
      post 'update_csv_map'
      post 'delete_csv_map'
      post 'delete_map'
      get 'pull_store_inventory'
      get 'push_store_inventory'
      get 'check_imported_folder'
      post 'toggle_shopify_sync'
      post 'toggle_shopline_sync'
    end
  end

  resources :users do
    collection do
      get 'get_roles'
      get 'let_user_be_created'
      post 'delete_user'
      post 'duplicate_user'
      post 'change_user_status'
      post 'delete_role'
      post 'createUpdateUser'
      post 'update_user_status'
      get 'get_user_email'
      post 'update_email'
      put 'update_password'
      post 'update_login_date'
      get 'get_email'
      get 'get_super_admin_email'
      get 'modify_plan'
      get 'get_subscription_info'
      get 'invoices'
    end
    member do
      put 'create_role'
      get 'print_confirmation_code'
    end
  end

  resources :exportsettings do
    collection do
      get 'get_export_settings'
      put 'update_export_settings'
      get 'order_exports'
      get 'email_stats'
      get 'daily_packed'
    end
  end

  resources :scan_pack do
    collection do
      post 'scan_barcode'
      post 'reset_order_scan'
      post 'serial_scan'
      post 'click_scan'
      post 'product_instruction'
      post 'type_scan'
      post 'confirmation_code'
      post 'add_note'
      post 'send_out_of_stock_mail'
      post 'reset_order_scan'
      post 'get_shipment'
      post 'update_scanned'
      post 'send_request_to_api'
      post 'order_change_into_scanned'
      post 'product_first_scan'
      post 'scan_to_tote'
      post 'scan_pack_v2'
      post 'detect_discrepancy'
      post 'scan_pack_bug_report'
      post 'upload_image_on_s3'
      post 'verify_order_scanning'
    end
    member do
    end
  end

  resources :payments do
    collection do
      get 'default_card'
      delete 'delete_cards'
    end
  end

  resources :specials do
    collection do
    end
  end

  resources :order_activities do
    member do
      put 'acknowledge'
    end
  end

  resources :product_kit_activities do
    member do
      put 'acknowledge'
    end
  end

  Rails.application.routes.draw do
    resources :order_tags, only: [:index, :create, :update] do
      collection do
        get 'search'
        post 'create_or_update'
      end
    end
  end
  

  resources :shopify do
    member do
      put 'disconnect'
      get 'complete'
    end

    collection do
      get 'auth'
      get 'callback'
      get 'preferences'
      get 'help'
      post 'get_auth'
      get 'connection_auth'
      get 'connection_callback'
      get 'recurring_tenant_charges'
      get 'update_customer_plan'
      get 'finalize_payment'
      get 'invalid_request'
      get 'payment_failed'
      post 'store_subscription_data'
      get 'get_store_data'
    end
  end

  # resources :big_commerce do
  #   member do
  #     get 'auth_callback'
  #   end
  #   collection do
  #     get 'bigcommerce'
  #   end
  # end

  resources :tenants do
    collection do
      post 'delete_tenant'
      post 'fix_product_data'
      post 'bulk_event_logs'
    end
    member do
      post 'create_duplicate'
      post 'update_tenant_list'
      post 'update_access_restrictions'
      post 'update_zero_subscription'
      post 'update_price_field'
      get 'list_activity_logs'
    end
  end

  resources :inventory_warehouse do
    collection do
      put 'changestatus'
      put 'destroy'
      get 'available_users'
    end
    member do
      post 'edit_user_perms'
    end
  end

  resources :subscriptions do
    collection do
      get 'select_plan'
      get 'plan_info'
      post 'confirm_payment'
      get 'valid_tenant_name'
      get 'valid_email'
      get 'validate_coupon_id'
      get 'complete'
      get 'shopify_final_process'
      get 'get_one_time_payment_fee'
      post 'create_payment_intent'
    end
  end

  get '/cost_calculator' => 'cost_calculators#index'
  get '/email_calculations' => 'cost_calculators#email_calculations'

  resources :stripe do
    collection do
      post 'webhook'
    end
  end

  resources :dashboard do
    collection do
      get 'exceptions'
      get 'get_stat_stream_manually'
      get 'daily_packed_percentage'
      post 'download_daily_packed_csv'
      get 'process_missing_data'
    end
    post 'generate_stats'
  end
  post '/dashboard/update_to_avg_datapoint' => 'dashboard#update_to_avg_datapoint'

  resources :box do
    collection do
      put 'remove_from_box'
      put 'remove_empty'
      put 'delete_box'
    end
  end

  # Put things in this 'internal' namespace that isn't really part of the public product
  namespace :internal, path: '__' do
    get 'health', to: 'health_check#index'
  end

  # External APIs authorized by Developer ApiKey
  namespace :external do
    resources :orders, only: [], defaults: { format: 'json' } do
      post :retrieve, on: :collection
    end
  end

  namespace :webhooks do
    resources :shipstation, only: [], defaults: { format: 'json' } do
      post ':credential_id/import', on: :collection, action: :import
    end
  end

  resource :print, only: [] do
    collection do
      get '/qz_certificate' => 'print#qz_certificate'
      post '/qz_sign' => 'print#qz_sign'
    end
  end

  resources :api_keys, only: %i[create destroy]

  resources :groovepacker_webhooks, only: %i[create update] do
    delete 'delete_webhooks', on: :collection
  end

  resources :webhooks, only: [] do
    collection do
      post '/shop/redact' => 'webhooks#delete_shop'
      post '/customers/redact' => 'webhooks#delete_customer'
      post '/customers/data_request' => 'webhooks#show_customer'
      post '/orders_create' => 'webhooks#orders_create'
      post '/orders_update' => 'webhooks#orders_update'
    end
  end

  resources :print_pdf_links do
    collection do
      get 'get_pdf_list'
    end
    member do
      put 'update_is_printed'
    end
  end

  get '*path' => redirect('/')
  post '*path' => redirect('/')
end
