# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20140219231144) do

  create_table "amazon_credentials", :force => true do |t|
    t.string   "merchant_id",                                     :null => false
    t.string   "marketplace_id",                                  :null => false
    t.integer  "store_id"
    t.datetime "created_at",                                      :null => false
    t.datetime "updated_at",                                      :null => false
    t.boolean  "import_products",              :default => false, :null => false
    t.boolean  "import_images",                :default => false, :null => false
    t.string   "productreport_id"
    t.string   "productgenerated_report_id"
    t.datetime "productgenerated_report_date"
  end

  create_table "csv_mappings", :force => true do |t|
    t.integer  "store_id"
    t.text     "order_map"
    t.text     "product_map"
    t.datetime "created_at",  :null => false
    t.datetime "updated_at",  :null => false
  end

  create_table "ebay_credentials", :force => true do |t|
    t.integer  "store_id"
    t.datetime "created_at",                              :null => false
    t.datetime "updated_at",                              :null => false
    t.boolean  "import_products",      :default => false, :null => false
    t.boolean  "import_images",        :default => false, :null => false
    t.date     "ebay_auth_expiration"
    t.text     "productauth_token"
    t.text     "auth_token"
  end

  create_table "inventory_warehouses", :force => true do |t|
    t.string   "name",                               :null => false
    t.string   "location"
    t.datetime "created_at",                         :null => false
    t.datetime "updated_at",                         :null => false
    t.string   "status",     :default => "inactive"
  end

  create_table "magento_credentials", :force => true do |t|
    t.string   "host",                               :null => false
    t.string   "username",                           :null => false
    t.string   "password",                           :null => false
    t.integer  "store_id",                           :null => false
    t.datetime "created_at",                         :null => false
    t.datetime "updated_at",                         :null => false
    t.string   "api_key",         :default => "",    :null => false
    t.boolean  "import_products", :default => false, :null => false
    t.boolean  "import_images",   :default => false, :null => false
  end

  create_table "order_activities", :force => true do |t|
    t.datetime "activitytime"
    t.integer  "order_id"
    t.integer  "user_id"
    t.string   "action"
    t.datetime "created_at",   :null => false
    t.datetime "updated_at",   :null => false
    t.string   "username"
  end

  add_index "order_activities", ["order_id"], :name => "index_order_activities_on_order_id"
  add_index "order_activities", ["user_id"], :name => "index_order_activities_on_user_id"

  create_table "order_exceptions", :force => true do |t|
    t.string   "reason"
    t.string   "description"
    t.integer  "user_id"
    t.datetime "created_at",  :null => false
    t.datetime "updated_at",  :null => false
    t.integer  "order_id"
  end

  add_index "order_exceptions", ["order_id"], :name => "index_order_exceptions_on_order_id"
  add_index "order_exceptions", ["user_id"], :name => "index_order_exceptions_on_user_id"

  create_table "order_item_kit_product", :force => true do |t|
    t.string   "scanned_status",      :default => "unscanned"
    t.integer  "scanned_qty",         :default => 0
    t.integer  "order_item_id"
    t.integer  "product_kit_skus_id"
    t.datetime "created_at",                                   :null => false
    t.datetime "updated_at",                                   :null => false
  end

  add_index "order_item_kit_product", ["order_item_id"], :name => "index_order_item_kit_product_on_order_item_id"
  add_index "order_item_kit_product", ["product_kit_skus_id"], :name => "index_order_item_kit_product_on_product_kit_skus_id"

  create_table "order_item_kit_products", :force => true do |t|
    t.integer  "order_item_id"
    t.integer  "product_kit_skus_id"
    t.string   "scanned_status",      :default => "unscanned"
    t.integer  "scanned_qty",         :default => 0
    t.datetime "created_at",                                   :null => false
    t.datetime "updated_at",                                   :null => false
  end

  add_index "order_item_kit_products", ["order_item_id"], :name => "index_order_item_kit_products_on_order_item_id"
  add_index "order_item_kit_products", ["product_kit_skus_id"], :name => "index_order_item_kit_products_on_product_kit_skus_id"

  create_table "order_items", :force => true do |t|
    t.string   "sku"
    t.integer  "qty"
    t.decimal  "price",                 :precision => 10, :scale => 0
    t.decimal  "row_total",             :precision => 10, :scale => 0
    t.integer  "order_id"
    t.datetime "created_at",                                                                     :null => false
    t.datetime "updated_at",                                                                     :null => false
    t.string   "name",                                                 :default => "",           :null => false
    t.integer  "product_id"
    t.string   "scanned_status",                                       :default => "notscanned"
    t.integer  "scanned_qty",                                          :default => 0
    t.boolean  "kit_split",                                            :default => false
    t.integer  "kit_split_qty",                                        :default => 0
    t.integer  "kit_split_scanned_qty",                                :default => 0
    t.integer  "single_scanned_qty",                                   :default => 0
  end

  add_index "order_items", ["order_id"], :name => "index_order_items_on_order_id"

  create_table "order_shippings", :force => true do |t|
    t.string   "firstname"
    t.string   "lastname"
    t.string   "email"
    t.string   "streetaddress1"
    t.string   "streetaddress2"
    t.string   "city"
    t.string   "region"
    t.string   "postcode"
    t.string   "country"
    t.string   "description"
    t.integer  "order_id"
    t.datetime "created_at",     :null => false
    t.datetime "updated_at",     :null => false
  end

  create_table "order_tags", :force => true do |t|
    t.string   "name",                          :null => false
    t.string   "color",                         :null => false
    t.string   "mark_place", :default => "0"
    t.datetime "created_at",                    :null => false
    t.datetime "updated_at",                    :null => false
    t.boolean  "predefined", :default => false
  end

  create_table "order_tags_orders", :id => false, :force => true do |t|
    t.integer "order_id"
    t.integer "order_tag_id"
  end

  add_index "order_tags_orders", ["order_id", "order_tag_id"], :name => "index_order_tags_orders_on_order_id_and_order_tag_id"

  create_table "orders", :force => true do |t|
    t.string   "increment_id"
    t.datetime "order_placed_time"
    t.string   "sku"
    t.text     "customer_comments"
    t.integer  "store_id"
    t.integer  "qty"
    t.string   "price"
    t.string   "firstname"
    t.string   "lastname"
    t.string   "email"
    t.text     "address_1"
    t.text     "address_2"
    t.string   "city"
    t.string   "state"
    t.string   "postcode"
    t.string   "country"
    t.string   "method"
    t.datetime "created_at",         :null => false
    t.datetime "updated_at",         :null => false
    t.string   "notes_internal"
    t.string   "notes_toPacker"
    t.string   "notes_fromPacker"
    t.boolean  "tracking_processed"
    t.string   "status"
    t.date     "scanned_on"
    t.string   "tracking_num"
    t.string   "company"
  end

  create_table "orders_import_summaries", :force => true do |t|
    t.integer  "total_retrieved"
    t.integer  "success_imported"
    t.integer  "previous_imported"
    t.boolean  "status"
    t.string   "error_message"
    t.integer  "store_id"
    t.datetime "created_at",        :null => false
    t.datetime "updated_at",        :null => false
  end

  add_index "orders_import_summaries", ["store_id"], :name => "index_orders_import_summaries_on_store_id"

  create_table "product_barcodes", :force => true do |t|
    t.integer  "product_id"
    t.string   "barcode"
    t.datetime "created_at",                :null => false
    t.datetime "updated_at",                :null => false
    t.integer  "order",      :default => 0
  end

  add_index "product_barcodes", ["product_id"], :name => "index_product_barcodes_on_product_id"

  create_table "product_cats", :force => true do |t|
    t.string   "category"
    t.integer  "product_id"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  add_index "product_cats", ["product_id"], :name => "index_product_cats_on_product_id"

  create_table "product_images", :force => true do |t|
    t.integer  "product_id"
    t.string   "image"
    t.datetime "created_at",                :null => false
    t.datetime "updated_at",                :null => false
    t.string   "caption"
    t.integer  "order",      :default => 0
  end

  add_index "product_images", ["product_id"], :name => "index_product_images_on_product_id"

  create_table "product_inventory_warehouses", :force => true do |t|
    t.integer  "qty"
    t.integer  "product_id"
    t.datetime "created_at",             :null => false
    t.datetime "updated_at",             :null => false
    t.string   "alert"
    t.string   "location_primary"
    t.string   "location_secondary"
    t.string   "name"
    t.string   "location"
    t.integer  "inventory_warehouse_id"
  end

  add_index "product_inventory_warehouses", ["inventory_warehouse_id"], :name => "index_product_inventory_warehouses_on_inventory_warehouse_id"
  add_index "product_inventory_warehouses", ["product_id"], :name => "index_product_inventory_warehouses_on_product_id"

  create_table "product_kit_skus", :force => true do |t|
    t.integer  "product_id"
    t.datetime "created_at",                        :null => false
    t.datetime "updated_at",                        :null => false
    t.integer  "option_product_id"
    t.integer  "qty",               :default => 0
    t.integer  "packing_order",     :default => 50
  end

  add_index "product_kit_skus", ["product_id"], :name => "index_product_kit_skus_on_product_id"

  create_table "product_skus", :force => true do |t|
    t.string   "sku"
    t.string   "purpose"
    t.integer  "product_id"
    t.datetime "created_at",                :null => false
    t.datetime "updated_at",                :null => false
    t.integer  "order",      :default => 0
  end

  add_index "product_skus", ["product_id"], :name => "index_product_skus_on_product_id"

  create_table "products", :force => true do |t|
    t.string   "store_product_id",                                       :null => false
    t.string   "name",                                                   :null => false
    t.string   "product_type"
    t.integer  "store_id",                                               :null => false
    t.datetime "created_at",                                             :null => false
    t.datetime "updated_at",                                             :null => false
    t.string   "inv_wh1"
    t.string   "status",                          :default => "new"
    t.text     "spl_instructions_4_packer"
    t.boolean  "spl_instructions_4_confirmation", :default => false
    t.text     "alternate_location"
    t.text     "barcode"
    t.boolean  "is_skippable",                    :default => false
    t.integer  "packing_placement",               :default => 50
    t.integer  "pack_time_adj"
    t.string   "kit_parsing",                     :default => "depends"
    t.integer  "is_kit",                          :default => 0
    t.boolean  "disable_conf_req",                :default => false
  end

  add_index "products", ["store_id"], :name => "index_products_on_store_id"

  create_table "roles", :force => true do |t|
    t.string   "name"
    t.integer  "resource_id"
    t.string   "resource_type"
    t.datetime "created_at",    :null => false
    t.datetime "updated_at",    :null => false
  end

  add_index "roles", ["name", "resource_type", "resource_id"], :name => "index_roles_on_name_and_resource_type_and_resource_id"
  add_index "roles", ["name"], :name => "index_roles_on_name"

  create_table "stores", :force => true do |t|
    t.string   "name",                          :null => false
    t.boolean  "status",     :default => false, :null => false
    t.string   "store_type",                    :null => false
    t.date     "order_date"
    t.datetime "created_at",                    :null => false
    t.datetime "updated_at",                    :null => false
  end

  create_table "users", :force => true do |t|
    t.string   "encrypted_password",     :default => "",    :null => false
    t.string   "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",          :default => 0
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string   "current_sign_in_ip"
    t.string   "last_sign_in_ip"
    t.datetime "created_at",                                :null => false
    t.datetime "updated_at",                                :null => false
    t.string   "username",               :default => "",    :null => false
    t.string   "email",                  :default => "",    :null => false
    t.boolean  "access_scanpack",        :default => false, :null => false
    t.boolean  "access_orders",          :default => false, :null => false
    t.boolean  "access_products",        :default => false, :null => false
    t.boolean  "access_settings",        :default => false, :null => false
    t.boolean  "active",                 :default => false, :null => false
    t.boolean  "edit_product_details",   :default => false, :null => false
    t.boolean  "add_products",           :default => false, :null => false
    t.boolean  "edit_products",          :default => false, :null => false
    t.boolean  "delete_products",        :default => false, :null => false
    t.boolean  "import_products",        :default => false, :null => false
    t.boolean  "edit_product_import",    :default => false, :null => false
    t.boolean  "import_orders",          :default => false, :null => false
    t.boolean  "change_order_status",    :default => false, :null => false
    t.boolean  "createEdit_from_packer", :default => false, :null => false
    t.boolean  "createEdit_to_packer",   :default => false, :null => false
    t.boolean  "add_order_items",        :default => false, :null => false
    t.boolean  "remove_order_items",     :default => false, :null => false
    t.boolean  "change_quantity_items",  :default => false, :null => false
    t.boolean  "view_packing_ex",        :default => false, :null => false
    t.boolean  "create_packing_ex",      :default => false, :null => false
    t.boolean  "edit_packing_ex",        :default => false, :null => false
    t.boolean  "create_users",           :default => false, :null => false
    t.boolean  "remove_users",           :default => false, :null => false
    t.boolean  "edit_user_info",         :default => false, :null => false
    t.boolean  "edit_user_permissions",  :default => false, :null => false
    t.boolean  "is_super_admin",         :default => false, :null => false
    t.boolean  "edit_general_prefs",     :default => false, :null => false
    t.boolean  "edit_scanning_prefs",    :default => false, :null => false
    t.boolean  "edit_user_status",       :default => false, :null => false
    t.boolean  "add_order_items_ALL",    :default => false, :null => false
    t.string   "other"
    t.string   "name"
    t.string   "confirmation_code",      :default => "",    :null => false
    t.integer  "inventory_warehouse_id"
  end

  add_index "users", ["inventory_warehouse_id"], :name => "index_users_on_inventory_warehouse_id"
  add_index "users", ["reset_password_token"], :name => "index_users_on_reset_password_token", :unique => true

  create_table "users_roles", :id => false, :force => true do |t|
    t.integer "user_id"
    t.integer "role_id"
  end

  add_index "users_roles", ["user_id", "role_id"], :name => "index_users_roles_on_user_id_and_role_id"

end
