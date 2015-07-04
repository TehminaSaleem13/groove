Groovepacks::Application.routes.draw do


  match 'subscriptions', :to => 'subscriptions#new', :as => 'subscriptions'
  match 'subscriptions_login', :to => 'subscriptions#login', :as => 'subscriptions/login'
  # match 'subscriptions/new', :to => 'subscriptions#new'
  # match 'subscriptions/show', :to => 'subscriptions#show'
  # get "subscriptions/show"
  get "inventory_warehouse/create"

  get "inventory_warehouse/update"

  get "inventory_warehouse/show"

  get "inventory_warehouse/index"

  get "inventory_warehouse/destroy"

  get "inventory_warehouse/adduser"

  get "inventory_warehouse/removeuser"

  get "store_settings/createStore"

  get "store_settings/csvImportData"

  get "store_settings/csvDoImport"

  get "store_settings/changestorestatus"

  get "store_settings/editstore"

  get "store_settings/duplicatestore"

  get "store_settings/deletestore"

  get "user_settings/userslist"

  get "user_settings/createUser"

  get "user_settings/changeuserstatus"

  get "user_settings/edituser"

  get "user_settings/duplicateuser"

  get "user_settings/deleteuser"

  get "home/index"

  devise_for :users

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

  resources :payments do
    collection do
      get 'default_card'
      delete 'delete_cards'
    end
    # member do
    #   put 'add_new_card'
    # end
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
      get 'auth'
      put 'disconnect'
      get 'complete'
    end

    collection do
      get 'callback'
      get 'preferences'
      get 'help'
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
  match ':controller(/:action(/:id))(.:format)'
end
