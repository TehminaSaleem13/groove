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

ActiveRecord::Schema.define(:version => 20160519072456) do

  create_table "access_restrictions", :force => true do |t|
    t.integer  "num_users",                           :default => 0,     :null => false
    t.integer  "num_shipments",                       :default => 0,     :null => false
    t.integer  "num_import_sources",                  :default => 0,     :null => false
    t.datetime "created_at",                                             :null => false
    t.datetime "updated_at",                                             :null => false
    t.integer  "total_scanned_shipments",             :default => 0,     :null => false
    t.boolean  "allow_bc_inv_push",                   :default => false
    t.boolean  "allow_mg_rest_inv_push",              :default => false
    t.boolean  "allow_shopify_inv_push",              :default => false
    t.boolean  "allow_teapplix_inv_push",             :default => false
    t.boolean  "allow_magento_soap_tracking_no_push", :default => false
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
    t.string   "mws_auth_token"
  end

  create_table "big_commerce_credentials", :force => true do |t|
    t.integer  "store_id"
    t.string   "shop_name"
    t.string   "store_hash"
    t.string   "access_token"
    t.datetime "created_at",       :null => false
    t.datetime "updated_at",       :null => false
    t.datetime "last_imported_at"
  end

  create_table "column_preferences", :force => true do |t|
    t.integer  "user_id"
    t.string   "identifier"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
    t.text     "theads"
  end

  add_index "column_preferences", ["user_id"], :name => "index_column_preferences_on_user_id"

  create_table "coupons", :force => true do |t|
    t.string   "coupon_id",                                      :null => false
    t.integer  "percent_off"
    t.decimal  "amount_off",      :precision => 10, :scale => 0
    t.string   "duration"
    t.date     "redeem_by"
    t.integer  "max_redemptions"
    t.integer  "times_redeemed"
    t.boolean  "is_valid",                                       :null => false
    t.datetime "created_at",                                     :null => false
    t.datetime "updated_at",                                     :null => false
  end

  create_table "csv_mappings", :force => true do |t|
    t.integer  "store_id"
    t.text     "order_map"
    t.text     "product_map"
    t.datetime "created_at",         :null => false
    t.datetime "updated_at",         :null => false
    t.integer  "product_csv_map_id"
    t.integer  "order_csv_map_id"
    t.integer  "kit_csv_map_id"
  end

  create_table "csv_maps", :force => true do |t|
    t.string   "kind"
    t.string   "name"
    t.boolean  "custom",     :default => true
    t.text     "map"
    t.datetime "created_at",                   :null => false
    t.datetime "updated_at",                   :null => false
  end

  create_table "csv_product_imports", :force => true do |t|
    t.string   "status"
    t.integer  "success",          :default => 0
    t.integer  "total",            :default => 0
    t.integer  "store_id"
    t.string   "current_sku"
    t.integer  "delayed_job_id"
    t.boolean  "cancel",           :default => false
    t.datetime "created_at",                          :null => false
    t.datetime "updated_at",                          :null => false
    t.integer  "success_imported", :default => 0
    t.integer  "duplicate_file",   :default => 0
    t.integer  "duplicate_db",     :default => 0
    t.integer  "success_updated",  :default => 0
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

  create_table "export_settings", :force => true do |t|
    t.boolean  "auto_email_export",         :default => true
    t.datetime "time_to_send_export_email"
    t.boolean  "send_export_email_on_mon",  :default => false
    t.boolean  "send_export_email_on_tue",  :default => false
    t.boolean  "send_export_email_on_wed",  :default => false
    t.boolean  "send_export_email_on_thu",  :default => false
    t.boolean  "send_export_email_on_fri",  :default => false
    t.boolean  "send_export_email_on_sat",  :default => false
    t.boolean  "send_export_email_on_sun",  :default => false
    t.datetime "last_exported"
    t.string   "export_orders_option",      :default => "on_same_day"
    t.string   "order_export_type",         :default => "include_all"
    t.string   "order_export_email"
    t.datetime "created_at",                                           :null => false
    t.datetime "updated_at",                                           :null => false
    t.datetime "start_time"
    t.datetime "end_time"
    t.boolean  "manual_export",             :default => false
  end

  create_table "ftp_credentials", :force => true do |t|
    t.string   "host"
    t.integer  "port",                   :default => 21
    t.string   "username",               :default => ""
    t.string   "password",               :default => ""
    t.integer  "store_id",                                  :null => false
    t.datetime "created_at",                                :null => false
    t.datetime "updated_at",                                :null => false
    t.string   "connection_method",      :default => "ftp"
    t.boolean  "connection_established", :default => false
    t.boolean  "use_ftp_import",         :default => false
  end

  create_table "general_settings", :force => true do |t|
    t.boolean  "inventory_tracking",                :default => false
    t.boolean  "low_inventory_alert_email",         :default => false
    t.string   "low_inventory_email_address",       :default => ""
    t.boolean  "hold_orders_due_to_inventory",      :default => false
    t.string   "conf_req_on_notes_to_packer",       :default => "optional"
    t.string   "send_email_for_packer_notes",       :default => "always"
    t.string   "email_address_for_packer_notes",    :default => ""
    t.datetime "created_at",                                                           :null => false
    t.datetime "updated_at",                                                           :null => false
    t.integer  "default_low_inventory_alert_limit", :default => 1
    t.boolean  "send_email_on_mon",                 :default => false
    t.boolean  "send_email_on_tue",                 :default => false
    t.boolean  "send_email_on_wed",                 :default => false
    t.boolean  "send_email_on_thurs",               :default => false
    t.boolean  "send_email_on_fri",                 :default => false
    t.boolean  "send_email_on_sat",                 :default => false
    t.boolean  "send_email_on_sun",                 :default => false
    t.datetime "time_to_send_email",                :default => '2000-01-01 00:00:00'
    t.string   "product_weight_format"
    t.string   "packing_slip_size",                 :default => "4 x 6"
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
    t.boolean  "strict_cc",                         :default => false
    t.string   "conf_code_product_instruction",     :default => "optional"
    t.string   "admin_email"
    t.string   "export_items",                      :default => "disabled"
    t.string   "custom_field_one",                  :default => "Custom 1"
    t.string   "custom_field_two",                  :default => "Custom 2"
    t.integer  "max_time_per_item",                 :default => 10
    t.string   "export_csv_email"
  end

  create_table "generate_barcodes", :force => true do |t|
    t.string   "status"
    t.string   "url"
    t.datetime "created_at",                                 :null => false
    t.datetime "updated_at",                                 :null => false
    t.integer  "user_id"
    t.string   "current_increment_id"
    t.integer  "current_order_position"
    t.integer  "total_orders"
    t.boolean  "cancel",                  :default => false
    t.string   "next_order_increment_id"
    t.integer  "delayed_job_id"
  end

  add_index "generate_barcodes", ["user_id"], :name => "index_generate_barcodes_on_user_id"

  create_table "groove_bulk_actions", :force => true do |t|
    t.string   "identifier",                          :null => false
    t.string   "activity",                            :null => false
    t.integer  "total",      :default => 0
    t.integer  "completed",  :default => 0
    t.string   "status",     :default => "scheduled"
    t.string   "current"
    t.text     "messages"
    t.boolean  "cancel",     :default => false
    t.datetime "created_at",                          :null => false
    t.datetime "updated_at",                          :null => false
  end

  create_table "import_items", :force => true do |t|
    t.string   "status"
    t.integer  "store_id"
    t.integer  "success_imported",            :default => 0
    t.integer  "previous_imported",           :default => 0
    t.datetime "created_at",                                         :null => false
    t.datetime "updated_at",                                         :null => false
    t.integer  "order_import_summary_id"
    t.integer  "to_import",                   :default => 0
    t.string   "current_increment_id",        :default => ""
    t.integer  "current_order_items",         :default => 0
    t.integer  "current_order_imported_item", :default => 0
    t.string   "message",                     :default => ""
    t.string   "import_type",                 :default => "regular"
    t.integer  "days"
    t.integer  "updated_orders_import"
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

  create_table "leader_boards", :force => true do |t|
    t.integer  "scan_time"
    t.integer  "order_id"
    t.integer  "order_item_count"
    t.datetime "created_at",       :null => false
    t.datetime "updated_at",       :null => false
  end

  create_table "magento_credentials", :force => true do |t|
    t.string   "host",                                       :null => false
    t.string   "username",                                   :null => false
    t.string   "password",                :default => ""
    t.integer  "store_id",                                   :null => false
    t.datetime "created_at",                                 :null => false
    t.datetime "updated_at",                                 :null => false
    t.string   "api_key",                 :default => "",    :null => false
    t.boolean  "import_products",         :default => false, :null => false
    t.boolean  "import_images",           :default => false, :null => false
    t.datetime "last_imported_at"
    t.boolean  "shall_import_processing", :default => false
    t.boolean  "shall_import_pending",    :default => false
    t.boolean  "shall_import_closed",     :default => false
    t.boolean  "shall_import_complete",   :default => false
    t.boolean  "shall_import_fraud",      :default => false
    t.boolean  "enable_status_update",    :default => false
    t.string   "status_to_update"
    t.boolean  "push_tracking_number",    :default => false
  end

  create_table "magento_rest_credentials", :force => true do |t|
    t.integer  "store_id"
    t.string   "host"
    t.string   "api_key"
    t.string   "api_secret"
    t.boolean  "import_images"
    t.boolean  "import_categories"
    t.datetime "created_at",                              :null => false
    t.datetime "updated_at",                              :null => false
    t.string   "access_token"
    t.string   "oauth_token_secret"
    t.datetime "last_imported_at"
    t.boolean  "gen_barcode_from_sku", :default => false
    t.string   "store_admin_url"
    t.string   "store_version"
    t.string   "store_token"
  end

  create_table "oauth_access_grants", :force => true do |t|
    t.integer  "resource_owner_id", :null => false
    t.integer  "application_id",    :null => false
    t.string   "token",             :null => false
    t.integer  "expires_in",        :null => false
    t.text     "redirect_uri",      :null => false
    t.datetime "created_at",        :null => false
    t.datetime "revoked_at"
    t.string   "scopes"
  end

  add_index "oauth_access_grants", ["token"], :name => "index_oauth_access_grants_on_token", :unique => true

  create_table "oauth_access_tokens", :force => true do |t|
    t.integer  "resource_owner_id"
    t.integer  "application_id"
    t.string   "token",             :null => false
    t.string   "refresh_token"
    t.integer  "expires_in"
    t.datetime "revoked_at"
    t.datetime "created_at",        :null => false
    t.string   "scopes"
  end

  add_index "oauth_access_tokens", ["refresh_token"], :name => "index_oauth_access_tokens_on_refresh_token", :unique => true
  add_index "oauth_access_tokens", ["resource_owner_id"], :name => "index_oauth_access_tokens_on_resource_owner_id"
  add_index "oauth_access_tokens", ["token"], :name => "index_oauth_access_tokens_on_token", :unique => true

  create_table "oauth_applications", :force => true do |t|
    t.string   "name",                         :null => false
    t.string   "uid",                          :null => false
    t.string   "secret",                       :null => false
    t.text     "redirect_uri",                 :null => false
    t.string   "scopes",       :default => "", :null => false
    t.datetime "created_at",                   :null => false
    t.datetime "updated_at",                   :null => false
  end

  add_index "oauth_applications", ["uid"], :name => "index_oauth_applications_on_uid", :unique => true

  create_table "order_activities", :force => true do |t|
    t.datetime "activitytime"
    t.integer  "order_id"
    t.integer  "user_id"
    t.string   "action"
    t.datetime "created_at",                       :null => false
    t.datetime "updated_at",                       :null => false
    t.string   "username"
    t.string   "activity_type"
    t.boolean  "acknowledged",  :default => false
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
    t.datetime "created_at",                                       :null => false
    t.datetime "updated_at",                                       :null => false
    t.string   "import_summary_type", :default => "import_orders"
    t.boolean  "display_summary",     :default => false
  end

  create_table "order_item_kit_product_scan_times", :force => true do |t|
    t.datetime "scan_start"
    t.datetime "scan_end"
    t.integer  "order_item_kit_product_id"
    t.datetime "created_at",                :null => false
    t.datetime "updated_at",                :null => false
  end

  create_table "order_item_kit_products", :force => true do |t|
    t.integer  "order_item_id"
    t.integer  "product_kit_skus_id"
    t.string   "scanned_status",      :default => "unscanned"
    t.integer  "scanned_qty",         :default => 0
    t.datetime "created_at",                                   :null => false
    t.datetime "updated_at",                                   :null => false
    t.integer  "clicked_qty",         :default => 0
  end

  add_index "order_item_kit_products", ["order_item_id"], :name => "index_order_item_kit_products_on_order_item_id"
  add_index "order_item_kit_products", ["product_kit_skus_id"], :name => "index_order_item_kit_products_on_product_kit_skus_id"

  create_table "order_item_order_serial_product_lots", :force => true do |t|
    t.integer  "order_item_id"
    t.integer  "product_lot_id"
    t.integer  "order_serial_id"
    t.datetime "created_at",                     :null => false
    t.datetime "updated_at",                     :null => false
    t.integer  "qty",             :default => 0
  end

  create_table "order_item_scan_times", :force => true do |t|
    t.datetime "scan_start"
    t.datetime "scan_end"
    t.integer  "order_item_id"
    t.datetime "created_at",    :null => false
    t.datetime "updated_at",    :null => false
  end

  create_table "order_items", :force => true do |t|
    t.string   "sku"
    t.integer  "qty"
    t.decimal  "price",                 :precision => 10, :scale => 2
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
    t.integer  "clicked_qty",                                          :default => 0
    t.boolean  "is_barcode_printed",                                   :default => false
  end

  add_index "order_items", ["order_id"], :name => "index_order_items_on_order_id"

  create_table "order_serials", :force => true do |t|
    t.integer  "order_id"
    t.integer  "product_id"
    t.string   "serial"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  add_index "order_serials", ["order_id"], :name => "index_order_serials_on_order_id"
  add_index "order_serials", ["product_id"], :name => "index_order_serials_on_product_id"

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
    t.datetime "created_at",                                                                 :null => false
    t.datetime "updated_at",                                                                 :null => false
    t.string   "store_order_id"
    t.text     "notes_internal"
    t.text     "notes_toPacker"
    t.text     "notes_fromPacker"
    t.boolean  "tracking_processed"
    t.string   "status"
    t.datetime "scanned_on"
    t.string   "tracking_num"
    t.string   "company"
    t.integer  "packing_user_id"
    t.string   "status_reason"
    t.string   "order_number"
    t.integer  "seller_id"
    t.integer  "order_status_id"
    t.string   "ship_name"
    t.decimal  "shipping_amount",          :precision => 9,  :scale => 2, :default => 0.0
    t.decimal  "order_total",              :precision => 9,  :scale => 2, :default => 0.0
    t.string   "notes_from_buyer"
    t.integer  "weight_oz"
    t.string   "non_hyphen_increment_id"
    t.boolean  "note_confirmation",                                       :default => false
    t.integer  "inaccurate_scan_count",                                   :default => 0
    t.datetime "scan_start_time"
    t.boolean  "reallocate_inventory",                                    :default => false
    t.datetime "last_suggested_at"
    t.integer  "total_scan_time",                                         :default => 0
    t.integer  "total_scan_count",                                        :default => 0
    t.decimal  "packing_score",            :precision => 10, :scale => 0, :default => 0
    t.string   "custom_field_one"
    t.string   "custom_field_two"
    t.boolean  "traced_in_dashboard",                                     :default => false
    t.boolean  "scanned_by_status_change",                                :default => false
  end

  create_table "product_barcodes", :force => true do |t|
    t.integer  "product_id"
    t.string   "barcode"
    t.datetime "created_at",                :null => false
    t.datetime "updated_at",                :null => false
    t.integer  "order",      :default => 0
    t.string   "lot_number"
  end

  add_index "product_barcodes", ["barcode"], :name => "index_product_barcodes_on_barcode"
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
    t.datetime "created_at",                                         :null => false
    t.datetime "updated_at",                                         :null => false
    t.string   "caption"
    t.integer  "order",                           :default => 0
    t.boolean  "added_to_receiving_instructions", :default => false
    t.string   "image_note"
  end

  add_index "product_images", ["product_id"], :name => "index_product_images_on_product_id"

  create_table "product_inventory_warehouses", :force => true do |t|
    t.string   "location"
    t.integer  "qty"
    t.integer  "product_id"
    t.datetime "created_at",                                               :null => false
    t.datetime "updated_at",                                               :null => false
    t.string   "alert"
    t.string   "location_primary",        :limit => 50
    t.string   "location_secondary",      :limit => 50
    t.string   "name"
    t.integer  "inventory_warehouse_id"
    t.integer  "available_inv",                         :default => 0,     :null => false
    t.integer  "allocated_inv",                         :default => 0,     :null => false
    t.string   "location_tertiary",       :limit => 50
    t.integer  "product_inv_alert_level",               :default => 0
    t.boolean  "product_inv_alert",                     :default => false
    t.integer  "sold_inv",                              :default => 0
  end

  add_index "product_inventory_warehouses", ["inventory_warehouse_id"], :name => "index_product_inventory_warehouses_on_inventory_warehouse_id"
  add_index "product_inventory_warehouses", ["product_id"], :name => "index_product_inventory_warehouses_on_product_id"

  create_table "product_kit_activities", :force => true do |t|
    t.integer  "product_id"
    t.string   "activity_message"
    t.string   "username"
    t.string   "activity_type"
    t.datetime "created_at",                          :null => false
    t.datetime "updated_at",                          :null => false
    t.boolean  "acknowledged",     :default => false
  end

  create_table "product_kit_skus", :force => true do |t|
    t.integer  "product_id"
    t.datetime "created_at",                        :null => false
    t.datetime "updated_at",                        :null => false
    t.integer  "option_product_id"
    t.integer  "qty",               :default => 0
    t.integer  "packing_order",     :default => 50
  end

  add_index "product_kit_skus", ["product_id"], :name => "index_product_kit_skus_on_product_id"

  create_table "product_lots", :force => true do |t|
    t.integer  "product_id"
    t.string   "lot_number"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  add_index "product_lots", ["product_id"], :name => "index_product_lots_on_product_id"

  create_table "product_skus", :force => true do |t|
    t.string   "sku"
    t.string   "purpose"
    t.integer  "product_id"
    t.datetime "created_at",                :null => false
    t.datetime "updated_at",                :null => false
    t.integer  "order",      :default => 0
  end

  add_index "product_skus", ["product_id"], :name => "index_product_skus_on_product_id"
  add_index "product_skus", ["sku"], :name => "index_product_skus_on_sku"

  create_table "products", :force => true do |t|
    t.string   "store_product_id"
    t.string   "name",                                                                                    :null => false
    t.string   "product_type"
    t.integer  "store_id",                                                                                :null => false
    t.datetime "created_at",                                                                              :null => false
    t.datetime "updated_at",                                                                              :null => false
    t.string   "status",                                                        :default => "new"
    t.text     "spl_instructions_4_packer"
    t.boolean  "spl_instructions_4_confirmation",                               :default => false
    t.boolean  "is_skippable",                                                  :default => false
    t.integer  "packing_placement",                                             :default => 50
    t.integer  "pack_time_adj"
    t.string   "kit_parsing",                                                   :default => "individual"
    t.integer  "is_kit",                                                        :default => 0
    t.boolean  "disable_conf_req",                                              :default => false
    t.integer  "total_avail_ext",                                               :default => 0,            :null => false
    t.decimal  "weight",                          :precision => 8, :scale => 2, :default => 0.0,          :null => false
    t.decimal  "shipping_weight",                 :precision => 8, :scale => 2, :default => 0.0
    t.boolean  "record_serial",                                                 :default => false
    t.string   "type_scan_enabled",                                             :default => "on"
    t.string   "click_scan_enabled",                                            :default => "on"
    t.string   "weight_format"
    t.boolean  "add_to_any_order",                                              :default => false
    t.string   "base_sku"
    t.boolean  "is_intangible",                                                 :default => false
    t.text     "product_receiving_instructions"
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
    t.boolean  "enable_click_sku",                        :default => true
    t.boolean  "ask_tracking_number",                     :default => false
    t.datetime "created_at",                                                                                    :null => false
    t.datetime "updated_at",                                                                                    :null => false
    t.boolean  "show_success_image",                      :default => true
    t.string   "success_image_src",                       :default => "/assets/images/scan_success.png"
    t.float    "success_image_time",                      :default => 0.5
    t.boolean  "show_fail_image",                         :default => true
    t.string   "fail_image_src",                          :default => "/assets/images/scan_fail.png"
    t.float    "fail_image_time",                         :default => 1.0
    t.boolean  "play_success_sound",                      :default => true
    t.string   "success_sound_url",                       :default => "/assets/sounds/scan_success.mp3"
    t.float    "success_sound_vol",                       :default => 0.75
    t.boolean  "play_fail_sound",                         :default => true
    t.string   "fail_sound_url",                          :default => "/assets/sounds/scan_fail.mp3"
    t.float    "fail_sound_vol",                          :default => 0.75
    t.boolean  "skip_code_enabled",                       :default => true
    t.string   "skip_code",                               :default => "SKIP"
    t.boolean  "note_from_packer_code_enabled",           :default => true
    t.string   "note_from_packer_code",                   :default => "NOTE"
    t.boolean  "service_issue_code_enabled",              :default => true
    t.string   "service_issue_code",                      :default => "ISSUE"
    t.boolean  "restart_code_enabled",                    :default => true
    t.string   "restart_code",                            :default => "RESTART"
    t.boolean  "show_order_complete_image",               :default => true
    t.string   "order_complete_image_src",                :default => "/assets/images/scan_order_complete.png"
    t.float    "order_complete_image_time",               :default => 1.0
    t.boolean  "play_order_complete_sound",               :default => true
    t.string   "order_complete_sound_url",                :default => "/assets/sounds/scan_order_complete.mp3"
    t.float    "order_complete_sound_vol",                :default => 0.75
    t.boolean  "type_scan_code_enabled",                  :default => true
    t.string   "type_scan_code",                          :default => "*"
    t.string   "post_scanning_option",                    :default => "None"
    t.string   "escape_string",                           :default => " - "
    t.boolean  "escape_string_enabled",                   :default => false
    t.boolean  "record_lot_number",                       :default => false
    t.boolean  "show_customer_notes",                     :default => false
    t.boolean  "show_internal_notes",                     :default => false
    t.boolean  "scan_by_tracking_number",                 :default => false
    t.boolean  "intangible_setting_enabled",              :default => false
    t.string   "intangible_string",                       :default => ""
    t.boolean  "post_scan_pause_enabled",                 :default => false
    t.float    "post_scan_pause_time",                    :default => 4.0
    t.boolean  "intangible_setting_gen_barcode_from_sku", :default => false
  end

  create_table "shipping_easy_credentials", :force => true do |t|
    t.integer  "store_id"
    t.string   "api_key"
    t.string   "api_secret"
    t.boolean  "import_ready_for_shipment", :default => false
    t.boolean  "import_shipped",            :default => false
    t.boolean  "gen_barcode_from_sku"
    t.datetime "created_at",                                   :null => false
    t.datetime "updated_at",                                   :null => false
    t.datetime "last_imported_at"
  end

  create_table "shipstation_credentials", :force => true do |t|
    t.string   "username",         :null => false
    t.string   "password",         :null => false
    t.datetime "created_at",       :null => false
    t.datetime "updated_at",       :null => false
    t.integer  "store_id"
    t.datetime "last_imported_at"
  end

  create_table "shipstation_rest_credentials", :force => true do |t|
    t.string   "api_key",                                             :null => false
    t.string   "api_secret",                                          :null => false
    t.date     "last_imported_at"
    t.integer  "store_id",                                            :null => false
    t.datetime "created_at",                                          :null => false
    t.datetime "updated_at",                                          :null => false
    t.boolean  "shall_import_awaiting_shipment",   :default => true
    t.boolean  "shall_import_shipped",             :default => false
    t.boolean  "warehouse_location_update",        :default => false
    t.boolean  "shall_import_customer_notes",      :default => false
    t.boolean  "shall_import_internal_notes",      :default => false
    t.integer  "regular_import_range",             :default => 3
    t.boolean  "gen_barcode_from_sku",             :default => false
    t.boolean  "shall_import_pending_fulfillment", :default => false
    t.datetime "quick_import_last_modified"
  end

  create_table "shipworks_credentials", :force => true do |t|
    t.string   "auth_token",                                   :null => false
    t.integer  "store_id",                                     :null => false
    t.datetime "created_at",                                   :null => false
    t.datetime "updated_at",                                   :null => false
    t.boolean  "shall_import_in_process",   :default => false
    t.boolean  "shall_import_new_order",    :default => false
    t.boolean  "shall_import_not_shipped",  :default => false
    t.boolean  "shall_import_shipped",      :default => false
    t.boolean  "shall_import_no_status",    :default => false
    t.boolean  "import_store_order_number", :default => false
    t.boolean  "gen_barcode_from_sku",      :default => false
  end

  create_table "shopify_credentials", :force => true do |t|
    t.string   "shop_name"
    t.string   "access_token"
    t.integer  "store_id"
    t.datetime "created_at",   :null => false
    t.datetime "updated_at",   :null => false
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
    t.boolean  "auto_update_products",          :default => false
    t.boolean  "update_inv",                    :default => false
  end

  create_table "subscriptions", :force => true do |t|
    t.string   "email"
    t.string   "tenant_name"
    t.decimal  "amount",                        :precision => 8, :scale => 2, :default => 0.0
    t.string   "stripe_user_token"
    t.string   "status"
    t.integer  "tenant_id"
    t.string   "stripe_transaction_identifier"
    t.datetime "created_at",                                                                             :null => false
    t.datetime "updated_at",                                                                             :null => false
    t.text     "transaction_errors"
    t.string   "subscription_plan_id"
    t.string   "customer_subscription_id"
    t.string   "stripe_customer_id"
    t.boolean  "is_active"
    t.string   "password",                                                                               :null => false
    t.string   "user_name",                                                                              :null => false
    t.string   "coupon_id"
    t.string   "progress",                                                    :default => "not_started"
  end

  create_table "sync_options", :force => true do |t|
    t.integer  "product_id"
    t.boolean  "sync_with_bc",               :default => false
    t.integer  "bc_product_id"
    t.datetime "created_at",                                    :null => false
    t.datetime "updated_at",                                    :null => false
    t.string   "bc_product_sku"
    t.boolean  "sync_with_mg_rest"
    t.integer  "mg_rest_product_id"
    t.boolean  "sync_with_shopify",          :default => false
    t.string   "shopify_product_variant_id"
    t.string   "mg_rest_product_sku"
    t.boolean  "sync_with_teapplix",         :default => false
    t.string   "teapplix_product_sku"
  end

  create_table "teapplix_credentials", :force => true do |t|
    t.integer  "store_id"
    t.string   "account_name"
    t.string   "username"
    t.string   "password"
    t.boolean  "import_shipped",       :default => false
    t.boolean  "import_open_orders",   :default => false
    t.datetime "last_imported_at"
    t.datetime "created_at",                              :null => false
    t.datetime "updated_at",                              :null => false
    t.boolean  "gen_barcode_from_sku", :default => false
  end

  create_table "tenants", :force => true do |t|
    t.string   "name"
    t.datetime "created_at",                             :null => false
    t.datetime "updated_at",                             :null => false
    t.integer  "duplicate_tenant_id"
    t.text     "note"
    t.boolean  "is_modified",         :default => false
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
    t.boolean  "active",                 :default => false, :null => false
    t.string   "other"
    t.string   "name"
    t.string   "confirmation_code",      :default => "",    :null => false
    t.integer  "inventory_warehouse_id"
    t.integer  "role_id"
    t.boolean  "view_dashboard",         :default => false
    t.boolean  "is_deleted",             :default => false
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
