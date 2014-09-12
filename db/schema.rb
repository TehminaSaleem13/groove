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

ActiveRecord::Schema.define(:version => 20140912144619) do

  create_table "access_restrictions", :force => true do |t|
    t.integer  "num_users",               :default => 0, :null => false
    t.integer  "num_shipments",           :default => 0, :null => false
    t.integer  "num_import_sources",      :default => 0, :null => false
    t.datetime "created_at",                             :null => false
    t.datetime "updated_at",                             :null => false
    t.integer  "total_scanned_shipments", :default => 0, :null => false
  end

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
    t.boolean  "show_shipping_weight_only",    :default => false
  end

  create_table "column_preferences", :force => true do |t|
    t.integer  "user_id"
    t.string   "identifier"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
    t.text     "theads"
  end

  add_index "column_preferences", ["user_id"], :name => "index_column_preferences_on_user_id"

  create_table "csv_mappings", :force => true do |t|
    t.integer  "store_id"
    t.text     "order_map"
    t.text     "product_map"
    t.datetime "created_at",  :null => false
    t.datetime "updated_at",  :null => false
  end

  create_table "delayed_jobs", :force => true do |t|
    t.integer  "priority",   :default => 0, :null => false
    t.integer  "attempts",   :default => 0, :null => false
    t.text     "handler",                   :null => false
    t.text     "last_error"
    t.datetime "run_at"
    t.datetime "locked_at"
    t.datetime "failed_at"
    t.string   "locked_by"
    t.string   "queue"
    t.datetime "created_at",                :null => false
    t.datetime "updated_at",                :null => false
  end

  add_index "delayed_jobs", ["priority", "run_at"], :name => "delayed_jobs_priority"

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

  create_table "general_settings", :force => true do |t|
    t.boolean  "inventory_tracking",                :default => true
    t.boolean  "low_inventory_alert_email",         :default => true
    t.string   "low_inventory_email_address",       :default => ""
    t.boolean  "hold_orders_due_to_inventory",      :default => true
    t.string   "conf_req_on_notes_to_packer",       :default => "optional"
    t.string   "send_email_for_packer_notes",       :default => "always"
    t.string   "email_address_for_packer_notes",    :default => ""
    t.datetime "created_at",                                                           :null => false
    t.datetime "updated_at",                                                           :null => false
    t.integer  "default_low_inventory_alert_limit", :default => 0
    t.boolean  "send_email_on_mon",                 :default => false
    t.boolean  "send_email_on_tue",                 :default => false
    t.boolean  "send_email_on_wed",                 :default => false
    t.boolean  "send_email_on_thurs",               :default => false
    t.boolean  "send_email_on_fri",                 :default => false
    t.boolean  "send_email_on_sat",                 :default => false
    t.boolean  "send_email_on_sun",                 :default => false
    t.datetime "time_to_send_email",                :default => '2000-01-01 00:00:00'
    t.string   "product_weight_format"
    t.string   "packing_slip_size"
    t.string   "packing_slip_orientation"
    t.text     "packing_slip_message_to_customer"
    t.boolean  "import_orders_on_mon",              :default => false
    t.boolean  "import_orders_on_tue",              :default => false
    t.boolean  "import_orders_on_wed",              :default => false
    t.boolean  "import_orders_on_thurs",            :default => false
    t.boolean  "import_orders_on_fri",              :default => false
    t.boolean  "import_orders_on_sat",              :default => false
    t.boolean  "import_orders_on_sun",              :default => false
    t.datetime "time_to_import_orders",             :default => '2000-01-01 00:00:00'
    t.boolean  "scheduled_order_import",            :default => true
    t.text     "tracking_error_order_not_found"
    t.text     "tracking_error_info_not_found"
  end

  create_table "generate_barcodes", :force => true do |t|
    t.string   "status"
    t.string   "url"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  create_table "import_items", :force => true do |t|
    t.string   "status"
    t.integer  "store_id"
    t.integer  "success_imported",        :default => 0
    t.integer  "previous_imported",       :default => 0
    t.datetime "created_at",                             :null => false
    t.datetime "updated_at",                             :null => false
    t.integer  "order_import_summary_id"
  end

  create_table "inventory_warehouses", :force => true do |t|
    t.string   "name",                               :null => false
    t.string   "location"
    t.datetime "created_at",                         :null => false
    t.datetime "updated_at",                         :null => false
    t.string   "status",     :default => "inactive"
    t.boolean  "is_default", :default => false
  end

  create_table "invoices", :force => true do |t|
    t.datetime "date"
    t.string   "invoice_id"
    t.string   "subscription_id"
    t.decimal  "amount",          :precision => 8, :scale => 2, :default => 0.0
    t.datetime "period_start"
    t.datetime "period_end"
    t.integer  "quantity"
    t.string   "plan_id"
    t.string   "customer_id"
    t.string   "charge_id"
    t.boolean  "attempted"
    t.boolean  "closed"
    t.boolean  "forgiven"
    t.boolean  "paid"
    t.datetime "created_at",                                                     :null => false
    t.datetime "updated_at",                                                     :null => false
  end

  create_table "magento_credentials", :force => true do |t|
    t.string   "host",                                :null => false
    t.string   "username",                            :null => false
    t.string   "password",         :default => ""
    t.integer  "store_id",                            :null => false
    t.datetime "created_at",                          :null => false
    t.datetime "updated_at",                          :null => false
    t.string   "api_key",          :default => "",    :null => false
    t.boolean  "import_products",  :default => false, :null => false
    t.boolean  "import_images",    :default => false, :null => false
    t.datetime "last_imported_at"
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

  create_table "order_import_summaries", :force => true do |t|
    t.integer  "user_id"
    t.string   "status"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

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
    t.datetime "created_at",                                                                      :null => false
    t.datetime "updated_at",                                                                      :null => false
    t.string   "name",                                                 :default => "",            :null => false
    t.integer  "product_id"
    t.string   "scanned_status",                                       :default => "notscanned"
    t.integer  "scanned_qty",                                          :default => 0
    t.boolean  "kit_split",                                            :default => false
    t.integer  "kit_split_qty",                                        :default => 0
    t.integer  "kit_split_scanned_qty",                                :default => 0
    t.integer  "single_scanned_qty",                                   :default => 0
    t.string   "inv_status",                                           :default => "unprocessed"
    t.string   "inv_status_reason",                                    :default => ""
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
    t.datetime "created_at",                                                             :null => false
    t.datetime "updated_at",                                                             :null => false
    t.string   "notes_internal"
    t.string   "notes_toPacker"
    t.string   "notes_fromPacker"
    t.boolean  "tracking_processed"
    t.string   "status"
    t.date     "scanned_on"
    t.string   "tracking_num"
    t.string   "company"
    t.integer  "packing_user_id"
    t.string   "status_reason"
    t.string   "order_number"
    t.integer  "seller_id"
    t.integer  "order_status_id"
    t.string   "ship_name"
    t.decimal  "shipping_amount",         :precision => 9, :scale => 2, :default => 0.0
    t.decimal  "order_total",             :precision => 9, :scale => 2, :default => 0.0
    t.string   "notes_from_buyer"
    t.integer  "weight_oz"
    t.string   "non_hyphen_increment_id"
  end

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
    t.string   "location"
    t.integer  "qty"
    t.integer  "product_id"
    t.datetime "created_at",                            :null => false
    t.datetime "updated_at",                            :null => false
    t.string   "alert"
    t.string   "location_primary"
    t.string   "location_secondary"
    t.string   "name"
    t.integer  "inventory_warehouse_id"
    t.integer  "available_inv",          :default => 0, :null => false
    t.integer  "allocated_inv",          :default => 0, :null => false
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
    t.string   "store_product_id",                                                                     :null => false
    t.string   "name",                                                                                 :null => false
    t.string   "product_type"
    t.integer  "store_id",                                                                             :null => false
    t.datetime "created_at",                                                                           :null => false
    t.datetime "updated_at",                                                                           :null => false
    t.string   "inv_wh1"
    t.string   "status",                                                        :default => "new"
    t.text     "spl_instructions_4_packer"
    t.boolean  "spl_instructions_4_confirmation",                               :default => false
    t.text     "alternate_location"
    t.text     "barcode"
    t.boolean  "is_skippable",                                                  :default => false
    t.integer  "packing_placement",                                             :default => 50
    t.integer  "pack_time_adj"
    t.string   "kit_parsing",                                                   :default => "depends"
    t.integer  "is_kit",                                                        :default => 0
    t.boolean  "disable_conf_req",                                              :default => false
    t.integer  "total_avail_ext",                                               :default => 0,         :null => false
    t.decimal  "weight",                          :precision => 8, :scale => 2, :default => 0.0,       :null => false
    t.decimal  "shipping_weight",                 :precision => 8, :scale => 2, :default => 0.0
  end

  add_index "products", ["store_id"], :name => "index_products_on_store_id"

  create_table "roles", :force => true do |t|
    t.string  "name",                                    :null => false
    t.boolean "display",              :default => false, :null => false
    t.boolean "custom",               :default => true,  :null => false
    t.boolean "add_edit_order_items", :default => false, :null => false
    t.boolean "import_orders",        :default => false, :null => false
    t.boolean "change_order_status",  :default => false, :null => false
    t.boolean "create_edit_notes",    :default => false, :null => false
    t.boolean "view_packing_ex",      :default => false, :null => false
    t.boolean "create_packing_ex",    :default => false, :null => false
    t.boolean "edit_packing_ex",      :default => false, :null => false
    t.boolean "delete_products",      :default => false, :null => false
    t.boolean "import_products",      :default => false, :null => false
    t.boolean "add_edit_products",    :default => false, :null => false
    t.boolean "add_edit_users",       :default => false, :null => false
    t.boolean "make_super_admin",     :default => false, :null => false
    t.boolean "access_scanpack",      :default => true,  :null => false
    t.boolean "access_orders",        :default => false, :null => false
    t.boolean "access_products",      :default => false, :null => false
    t.boolean "access_settings",      :default => false, :null => false
    t.boolean "edit_general_prefs",   :default => false, :null => false
    t.boolean "edit_scanning_prefs",  :default => false, :null => false
    t.boolean "add_edit_stores",      :default => false, :null => false
    t.boolean "create_backups",       :default => false, :null => false
    t.boolean "restore_backups",      :default => false, :null => false
  end

  create_table "scan_pack_settings", :force => true do |t|
    t.boolean  "enable_click_sku",    :default => true
    t.boolean  "ask_tracking_number", :default => false
    t.datetime "created_at",                                                         :null => false
    t.datetime "updated_at",                                                         :null => false
    t.boolean  "show_success_image",  :default => true
    t.string   "success_image_src",   :default => "/assets/images/scan_success.png"
    t.float    "success_image_time",  :default => 0.5
    t.boolean  "show_fail_image",     :default => true
    t.string   "fail_image_src",      :default => "/assets/images/scan_fail.png"
    t.float    "fail_image_time",     :default => 1.0
    t.boolean  "play_success_sound",  :default => true
    t.string   "success_sound_url",   :default => "/assets/sounds/scan_success.mp3"
    t.float    "success_sound_vol",   :default => 0.75
    t.boolean  "play_fail_sound",     :default => true
    t.string   "fail_sound_url",      :default => "/assets/sounds/scan_fail.mp3"
    t.float    "fail_sound_vol",      :default => 0.75
  end

  create_table "shipstation_credentials", :force => true do |t|
    t.string   "username",         :null => false
    t.string   "password",         :null => false
    t.datetime "created_at",       :null => false
    t.datetime "updated_at",       :null => false
    t.integer  "store_id"
    t.datetime "last_imported_at"
  end

  create_table "sold_inventory_warehouses", :force => true do |t|
    t.integer  "product_inventory_warehouses_id"
    t.integer  "sold_qty"
    t.datetime "sold_date"
    t.datetime "created_at",                      :null => false
    t.datetime "updated_at",                      :null => false
  end

  create_table "stores", :force => true do |t|
    t.string   "name",                                             :null => false
    t.boolean  "status",                        :default => false, :null => false
    t.string   "store_type",                                       :null => false
    t.date     "order_date"
    t.datetime "created_at",                                       :null => false
    t.datetime "updated_at",                                       :null => false
    t.integer  "inventory_warehouse_id"
    t.text     "thank_you_message_to_customer"
  end

  create_table "subscriptions", :force => true do |t|
    t.string   "email"
    t.string   "tenant_name"
    t.decimal  "amount",                        :precision => 8, :scale => 2, :default => 0.0
    t.string   "stripe_user_token"
    t.string   "status"
    t.integer  "tenant_id"
    t.string   "stripe_transaction_identifier"
    t.datetime "created_at",                                                                   :null => false
    t.datetime "updated_at",                                                                   :null => false
    t.text     "transaction_errors"
    t.string   "subscription_plan_id"
    t.string   "customer_subscription_id"
    t.string   "stripe_customer_id"
    t.boolean  "is_active"
    t.string   "password",                                                                     :null => false
    t.string   "user_name",                                                                    :null => false
  end

  create_table "tenants", :force => true do |t|
    t.string   "name"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  create_table "transactions", :force => true do |t|
    t.string   "transaction_id"
    t.decimal  "amount",            :precision => 8, :scale => 2, :default => 0.0
    t.string   "card_type"
    t.integer  "exp_month_of_card"
    t.integer  "exp_year_of_card"
    t.datetime "date_of_payment"
    t.integer  "subscription_id"
    t.datetime "created_at",                                                       :null => false
    t.datetime "updated_at",                                                       :null => false
  end

  create_table "user_inventory_permissions", :force => true do |t|
    t.integer "user_id",                                   :null => false
    t.integer "inventory_warehouse_id",                    :null => false
    t.boolean "see",                    :default => false, :null => false
    t.boolean "edit",                   :default => false, :null => false
  end

  add_index "user_inventory_permissions", ["user_id", "inventory_warehouse_id"], :name => "index_user_inventory_permissions_user_inventory", :unique => true

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
    t.boolean  "active",                 :default => false, :null => false
    t.string   "other"
    t.string   "name"
    t.string   "confirmation_code",      :default => "",    :null => false
    t.integer  "inventory_warehouse_id"
    t.integer  "role_id"
  end

  add_index "users", ["inventory_warehouse_id"], :name => "index_users_on_inventory_warehouse_id"
  add_index "users", ["reset_password_token"], :name => "index_users_on_reset_password_token", :unique => true
  add_index "users", ["role_id"], :name => "index_users_on_role_id"

  create_table "webhooks", :force => true do |t|
    t.binary   "event",      :limit => 16777215
    t.datetime "created_at",                     :null => false
    t.datetime "updated_at",                     :null => false
  end

end
