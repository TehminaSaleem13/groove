Groovepacks::Application.routes.draw do

  use_doorkeeper

  match 'subscriptions', :to => 'subscriptions#new', :as => 'subscriptions'
  match 'subscriptions_login', :to => 'subscriptions#login', :as => 'subscriptions/login'

  get "/404", :to => "specials#error_404"

  get "/422", :to => "specials#error_422"

  get "/500", :to => "specials#error_500"

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
  post "magento_rest/callback" => "magento_rest#callback"
  get "magento_rest/redirect" => "magento_rest#redirect"
  get 'stores/export_active_products' => 'stores#export_active_products'
  get '/settings/print_action_barcode/:id' => 'settings#print_action_barcode'

  get '/store_settings/handle_ebay_redirect' => 'stores#handle_ebay_redirect'

  # The priority is based upon order of creation:
  # first created -> highest priority.

  # Sample of regular route:
  #   match 'products/:id' => 'catalog#view'
  # Keep in mind you can assign values other than :controller and :action

  # Sample of named route:
  #   match 'products/:id/purchase' => 'catalog#purchase', :as => :purchase
  # This route can be invoked with purchase_url(:id => product.id)

  # Sample resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products
  root :to => "home#index"

  resources :home do
    collection do
      get 'userinfo'
      get 'request_socket_notifs'
    end
  end

  resources :orders do
    collection do
      get 'search'
      get 'import_orders'
      get 'import_all'
      post 'generate_pick_list'
      post 'generate_packing_slip'
      post 'order_items_export'
      post 'cancel_packing_slip'
      post 'delete_orders'
      post 'duplicate_orders'
      post 'change_orders_status'
      post 'update_order_list'
      post 'rollback'
      post 'remove_item_from_order'
      post 'update_item_in_order'
      post 'import_shipworks'
      get 'import'
      put 'cancel_import'
      post 'get_id'
    end
    member do
      post 'add_item_to_order'
      post 'record_exception'
      post 'clear_exception'
      get 'importorders'
    end
  end

  resources :products do
    collection do
      get 'import_products'
      get 'search'
      get 'import_images'
      get 'import_product_details'
      post 'delete_product'
      post 'duplicate_product'
      post 'change_product_status'
      post 'generate_barcode'
      post 'scan_per_product'
      post 'generate_products_csv'
      post 'update_product_list'
      post 'update_image'
      post 'update_intangibleness'
      post 'print_receiving_label'
    end
    member do
      get 'generate_barcode_slip'
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
      get 'get_columns_state'
      put 'update_settings'
      get 'get_scan_pack_settings'
      get 'order_exceptions'
      get 'order_serials'
      get 'export_csv'
      post 'restore'
      post 'save_columns_state'
      post 'cancel_bulk_action'
      post 'update_scan_pack_settings'
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
    end
    member do
      get 'verify_tags'
      put 'update_all_locations'
      get 'connect_and_retrieve'
      post 'create_update_ftp_credentials'
      post 'delete_ebay_token'
      get 'update_ebay_user_token'
      post 'csv_import_data'
      post 'csv_do_import'
      post 'csv_product_import_cancel'
      post 'update_csv_map'
      post 'delete_csv_map'
      get 'pull_store_inventory'
      get 'push_store_inventory'
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
      post 'reset_order_scan'
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
    end
    member do
      post   'create_duplicate'
      post 'update_tenant_list'
      post 'update_access_restrictions'
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
    end
  end

  resources :stripe do
    collection do
      post 'webhook'
    end
  end

  resources :dashboard do
    collection do
      get 'packing_stats'
      get 'packed_item_stats'
      get 'packing_speed'
      get 'main_summary'
      get 'exceptions'
      get 'leader_board'
    end
  end

  # Sample resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Sample resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Sample resource route with more complex sub-resources
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', :on => :collection
  #     end
  #   end

  # Sample resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end

  # You can have the root of your site routed with "root"
  # just remember to delete public/index.html.
  # root :to => 'welcome#index'

  # See how all your routes lay out with "rake routes"

  # This is a legacy wild controller route that's not recommended for RESTful applications.
  # Note: This route will make all actions in every controller accessible via GET requests.
  # match ':controller(/:action(/:id))(.:format)'
end
