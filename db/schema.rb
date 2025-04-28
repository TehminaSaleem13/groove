# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2025_04_25_154357) do

  create_table "access_restrictions", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "num_users", default: 0, null: false
    t.integer "num_shipments", default: 0, null: false
    t.integer "num_import_sources", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "total_scanned_shipments", default: 0, null: false
    t.boolean "allow_bc_inv_push", default: false
    t.boolean "allow_mg_rest_inv_push", default: false
    t.boolean "allow_shopify_inv_push", default: false
    t.boolean "allow_teapplix_inv_push", default: false
    t.boolean "allow_magento_soap_tracking_no_push", default: false
    t.integer "added_through_ui", default: 0
    t.boolean "allow_shopline_inv_push", default: false
    t.integer "administrative_users", default: 0, null: false
    t.integer "regular_users", default: 0, null: false
  end

  create_table "ahoy_events", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "visit_id"
    t.integer "user_id"
    t.string "name"
    t.text "properties", size: :long, collation: "utf8mb4_unicode_ci"
    t.timestamp "time"
    t.boolean "version_2", default: false
    t.index ["name", "time"], name: "index_ahoy_events_on_name_and_time"
    t.index ["user_id", "name"], name: "index_ahoy_events_on_user_id_and_name"
    t.index ["visit_id", "name"], name: "index_ahoy_events_on_visit_id_and_name"
  end

  create_table "amazon_credentials", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "merchant_id", default: ""
    t.string "marketplace_id", default: ""
    t.bigint "store_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "import_products", default: false, null: false
    t.boolean "import_images", default: false, null: false
    t.string "productreport_id"
    t.string "productgenerated_report_id"
    t.datetime "productgenerated_report_date"
    t.boolean "show_shipping_weight_only", default: false
    t.string "mws_auth_token"
    t.boolean "shipped_status", default: false
    t.boolean "unshipped_status", default: true
    t.datetime "last_imported_at"
    t.boolean "afn_fulfillment_channel", default: false
    t.boolean "mfn_fulfillment_channel", default: true
    t.index ["store_id"], name: "index_amazon_credentials_on_store_id"
  end

  create_table "api_keys", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "author_id", null: false
    t.string "token", null: false
    t.datetime "expires_at"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_id"], name: "index_api_keys_on_author_id"
    t.index ["token"], name: "index_api_keys_on_token", unique: true
  end

  create_table "big_commerce_credentials", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "store_id"
    t.string "shop_name"
    t.string "store_hash"
    t.string "access_token"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "last_imported_at"
  end

  create_table "boxes", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "order_id"
  end

  create_table "cart_rows", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "row_name"
    t.integer "row_count"
    t.bigint "cart_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["cart_id"], name: "index_cart_rows_on_cart_id"
  end

  create_table "carts", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "cart_id"
    t.string "cart_name"
    t.integer "number_of_totes"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "column_preferences", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "user_id"
    t.string "identifier"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "theads"
    t.index ["user_id"], name: "index_column_preferences_on_user_id"
  end

  create_table "coupons", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "coupon_id", null: false
    t.integer "percent_off"
    t.decimal "amount_off", precision: 10
    t.string "duration"
    t.date "redeem_by"
    t.integer "max_redemptions"
    t.integer "times_redeemed"
    t.boolean "is_valid", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "csv_import_log_entries", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "index"
    t.integer "csv_import_summary_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "csv_import_summaries", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "file_name"
    t.decimal "file_size", precision: 8, scale: 4, default: "0.0"
    t.string "import_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "log_record"
  end

  create_table "csv_mappings", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "store_id"
    t.text "order_map"
    t.text "product_map"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "product_csv_map_id"
    t.integer "order_csv_map_id"
    t.integer "kit_csv_map_id"
  end

  create_table "csv_maps", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "kind"
    t.string "name"
    t.boolean "custom", default: true
    t.text "map"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "csv_product_imports", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "status"
    t.integer "success", default: 0
    t.integer "total", default: 0
    t.integer "store_id"
    t.string "current_sku"
    t.integer "delayed_job_id"
    t.boolean "cancel", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "success_imported", default: 0
    t.integer "duplicate_file", default: 0
    t.integer "duplicate_db", default: 0
    t.integer "success_updated", default: 0
  end

  create_table "delayed_jobs", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "priority", default: 0, null: false
    t.integer "attempts", default: 0, null: false
    t.text "handler", null: false
    t.text "last_error"
    t.datetime "run_at"
    t.datetime "locked_at"
    t.datetime "failed_at"
    t.string "locked_by"
    t.string "queue"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "signature"
    t.text "args"
    t.string "tenant"
    t.index ["priority", "run_at"], name: "delayed_jobs_priority"
  end

  create_table "ebay_credentials", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "store_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "import_products", default: false, null: false
    t.boolean "import_images", default: false, null: false
    t.date "ebay_auth_expiration"
    t.text "productauth_token"
    t.text "auth_token"
    t.boolean "shipped_status", default: false
    t.boolean "unshipped_status", default: true
    t.index ["store_id"], name: "index_ebay_credentials_on_store_id"
  end

  create_table "event_logs", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.text "data", size: :long
    t.text "message"
    t.integer "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_event_logs_on_user_id"
  end

  create_table "export_settings", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.boolean "auto_email_export", default: true
    t.datetime "time_to_send_export_email"
    t.boolean "send_export_email_on_mon", default: false
    t.boolean "send_export_email_on_tue", default: false
    t.boolean "send_export_email_on_wed", default: false
    t.boolean "send_export_email_on_thu", default: false
    t.boolean "send_export_email_on_fri", default: false
    t.boolean "send_export_email_on_sat", default: false
    t.boolean "send_export_email_on_sun", default: false
    t.datetime "last_exported"
    t.string "export_orders_option", default: "on_same_day"
    t.string "order_export_type", default: "include_all"
    t.string "order_export_email"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "start_time"
    t.datetime "end_time"
    t.boolean "manual_export", default: false
    t.boolean "auto_stat_email_export", default: true
    t.datetime "time_to_send_stat_export_email"
    t.boolean "send_stat_export_email_on_mon", default: false
    t.boolean "send_stat_export_email_on_tue", default: false
    t.boolean "send_stat_export_email_on_wed", default: false
    t.boolean "send_stat_export_email_on_thu", default: false
    t.boolean "send_stat_export_email_on_fri", default: false
    t.boolean "send_stat_export_email_on_sat", default: false
    t.boolean "send_stat_export_email_on_sun", default: false
    t.string "stat_export_type", default: "1"
    t.string "stat_export_email"
    t.integer "processing_time", default: 0
    t.boolean "daily_packed_email_export", default: false
    t.datetime "time_to_send_daily_packed_export_email"
    t.boolean "daily_packed_email_on_mon", default: false
    t.boolean "daily_packed_email_on_tue", default: false
    t.boolean "daily_packed_email_on_wed", default: false
    t.boolean "daily_packed_email_on_thu", default: false
    t.boolean "daily_packed_email_on_fri", default: false
    t.boolean "daily_packed_email_on_sat", default: false
    t.boolean "daily_packed_email_on_sun", default: false
    t.string "daily_packed_export_type", default: "30"
    t.string "daily_packed_email"
    t.boolean "auto_ftp_export", default: false
    t.boolean "include_partially_scanned_orders", default: false
    t.boolean "include_partially_scanned_orders_user_stats", default: false
  end

  create_table "ftp_credentials", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "host"
    t.integer "port", default: 21
    t.string "username", default: ""
    t.string "password", default: ""
    t.bigint "store_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "connection_method", default: "ftp"
    t.boolean "connection_established", default: false
    t.boolean "use_ftp_import", default: false
    t.boolean "use_product_ftp_import", default: false
    t.string "product_ftp_connection_method", default: "ftp"
    t.string "product_ftp_host"
    t.string "product_ftp_username", default: ""
    t.string "product_ftp_password", default: ""
    t.boolean "product_ftp_connection_established", default: false
    t.index ["store_id"], name: "index_ftp_credentials_on_store_id"
  end

  create_table "general_settings", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.boolean "inventory_tracking", default: false
    t.boolean "low_inventory_alert_email", default: false
    t.string "low_inventory_email_address", default: ""
    t.boolean "hold_orders_due_to_inventory", default: false
    t.string "conf_req_on_notes_to_packer", default: "optional"
    t.string "send_email_for_packer_notes", default: "always"
    t.string "email_address_for_packer_notes", default: ""
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "default_low_inventory_alert_limit", default: 1
    t.boolean "send_email_on_mon", default: false
    t.boolean "send_email_on_tue", default: false
    t.boolean "send_email_on_wed", default: false
    t.boolean "send_email_on_thurs", default: false
    t.boolean "send_email_on_fri", default: false
    t.boolean "send_email_on_sat", default: false
    t.boolean "send_email_on_sun", default: false
    t.datetime "time_to_send_email"
    t.string "product_weight_format"
    t.string "packing_slip_size", default: "4 x 6"
    t.string "packing_slip_orientation"
    t.text "packing_slip_message_to_customer"
    t.boolean "import_orders_on_mon", default: false
    t.boolean "import_orders_on_tue", default: false
    t.boolean "import_orders_on_wed", default: false
    t.boolean "import_orders_on_thurs", default: false
    t.boolean "import_orders_on_fri", default: false
    t.boolean "import_orders_on_sat", default: false
    t.boolean "import_orders_on_sun", default: false
    t.datetime "time_to_import_orders"
    t.boolean "scheduled_order_import", default: true
    t.text "tracking_error_order_not_found"
    t.text "tracking_error_info_not_found"
    t.boolean "strict_cc", default: false
    t.string "conf_code_product_instruction", default: "optional"
    t.string "admin_email"
    t.string "export_items", default: "disabled"
    t.string "custom_field_one", default: "Custom 1"
    t.string "custom_field_two", default: "Custom 2"
    t.integer "max_time_per_item", default: 10
    t.string "export_csv_email"
    t.boolean "show_primary_bin_loc_in_barcodeslip", default: false
    t.string "time_zone"
    t.boolean "search_by_product", default: false
    t.boolean "auto_detect", default: true
    t.boolean "dst", default: true
    t.string "stat_status"
    t.text "cost_calculator_url"
    t.string "schedule_import_mode"
    t.boolean "master_switch", default: false
    t.boolean "html_print", default: false
    t.float "idle_timeout"
    t.boolean "hex_barcode", default: false
    t.datetime "from_import", default: "2000-01-01 00:00:00"
    t.datetime "to_import", default: "2000-01-01 23:59:00"
    t.boolean "multi_box_shipments", default: false
    t.string "per_box_packing_slips", default: "manually"
    t.string "custom_user_field_one"
    t.string "custom_user_field_two"
    t.string "email_address_for_billing_notification"
    t.boolean "display_kit_parts", default: false
    t.boolean "remove_order_items", default: false
    t.boolean "create_barcode_at_import", default: false
    t.boolean "print_post_scanning_barcodes", default: false
    t.boolean "print_packing_slips", default: false
    t.boolean "print_ss_shipping_labels", default: false
    t.string "per_box_shipping_label_creation", default: "per_box_shipping_label_creation_none"
    t.integer "barcode_length", default: 8
    t.string "starting_value", default: "10000000"
    t.boolean "show_sku_in_barcodeslip", default: true
    t.boolean "print_product_barcode_labels", default: false
    t.string "new_time_zone", default: "Eastern Time (US & Canada)"
    t.boolean "truncate_order_number_in_packing_slip", default: false
    t.string "truncated_string", default: "-"
    t.boolean "print_product_receiving_labels", default: false
    t.boolean "is_haptics_option", default: false
    t.string "email_address_for_report_out_of_stock", default: ""
    t.string "abbreviated_time_zone"
    t.boolean "delete_import_summary", default: false
    t.integer "slide_show_time", default: 15
    t.json "select_types", null: false
  end

  create_table "generate_barcodes", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "status"
    t.string "url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.string "current_increment_id"
    t.integer "current_order_position"
    t.integer "total_orders"
    t.boolean "cancel", default: false
    t.string "next_order_increment_id"
    t.integer "delayed_job_id"
    t.text "error_message"
    t.string "dimensions"
    t.string "print_type"
    t.index ["user_id"], name: "index_generate_barcodes_on_user_id"
  end

  create_table "groove_bulk_actions", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "identifier", null: false
    t.string "activity", null: false
    t.integer "total", default: 0
    t.integer "completed", default: 0
    t.string "status", default: "scheduled"
    t.string "current", limit: 5000, collation: "utf8mb4_unicode_ci"
    t.text "messages"
    t.boolean "cancel", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "groovepacker_webhooks", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "secret_key"
    t.string "url"
    t.string "event"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "import_items", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "status"
    t.integer "store_id"
    t.integer "success_imported", default: 0
    t.integer "previous_imported", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "order_import_summary_id"
    t.integer "to_import", default: 0
    t.string "current_increment_id", default: ""
    t.integer "current_order_items", default: 0
    t.integer "current_order_imported_item", default: 0
    t.string "message", default: ""
    t.string "import_type", default: "regular"
    t.integer "days"
    t.integer "updated_orders_import", default: 0
    t.text "import_error"
    t.integer "failed_count", default: 0
    t.string "importer_id"
  end

  create_table "inventory_reports_settings", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.boolean "send_email_on_mon", default: false, null: false
    t.boolean "send_email_on_tue", default: false, null: false
    t.boolean "send_email_on_wed", default: false, null: false
    t.boolean "send_email_on_thurs", default: false, null: false
    t.boolean "send_email_on_fri", default: false, null: false
    t.boolean "send_email_on_sat", default: false, null: false
    t.boolean "send_email_on_sun", default: false, null: false
    t.boolean "auto_email_report", default: false, null: false
    t.datetime "start_time"
    t.datetime "end_time"
    t.datetime "time_to_send_report_email"
    t.string "report_email"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "report_days_option", default: 1
  end

  create_table "inventory_warehouses", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name", null: false
    t.string "location"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "status", default: "inactive"
    t.boolean "is_default", default: false
  end

  create_table "invoices", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "date"
    t.string "invoice_id"
    t.string "subscription_id"
    t.decimal "amount", precision: 8, scale: 2, default: "0.0"
    t.datetime "period_start"
    t.datetime "period_end"
    t.integer "quantity"
    t.string "plan_id"
    t.string "customer_id"
    t.string "charge_id"
    t.boolean "attempted"
    t.boolean "closed"
    t.boolean "forgiven"
    t.boolean "paid"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "leader_boards", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "scan_time"
    t.integer "order_id"
    t.integer "order_item_count"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "magento_credentials", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "host"
    t.string "username"
    t.string "password", default: ""
    t.bigint "store_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "api_key", default: ""
    t.boolean "import_products", default: false, null: false
    t.boolean "import_images", default: false, null: false
    t.datetime "last_imported_at"
    t.boolean "shall_import_processing", default: false
    t.boolean "shall_import_pending", default: false
    t.boolean "shall_import_closed", default: false
    t.boolean "shall_import_complete", default: false
    t.boolean "shall_import_fraud", default: false
    t.boolean "enable_status_update", default: false
    t.string "status_to_update"
    t.boolean "push_tracking_number", default: false
    t.boolean "updated_patch", default: false
    t.index ["store_id"], name: "index_magento_credentials_on_store_id"
  end

  create_table "magento_rest_credentials", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "store_id"
    t.string "host"
    t.string "api_key"
    t.string "api_secret"
    t.boolean "import_images"
    t.boolean "import_categories"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "access_token"
    t.string "oauth_token_secret"
    t.datetime "last_imported_at"
    t.boolean "gen_barcode_from_sku", default: false
    t.string "store_admin_url"
    t.string "store_version"
    t.string "store_token"
  end

  create_table "oauth_access_grants", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "resource_owner_id", null: false
    t.integer "application_id", null: false
    t.string "token", null: false
    t.integer "expires_in", null: false
    t.text "redirect_uri", null: false
    t.datetime "created_at", null: false
    t.datetime "revoked_at"
    t.string "scopes"
    t.index ["token"], name: "index_oauth_access_grants_on_token", unique: true
  end

  create_table "oauth_access_tokens", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "resource_owner_id"
    t.integer "application_id"
    t.string "token", null: false
    t.string "refresh_token"
    t.integer "expires_in"
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.string "scopes"
    t.index ["refresh_token"], name: "index_oauth_access_tokens_on_refresh_token", unique: true
    t.index ["resource_owner_id"], name: "index_oauth_access_tokens_on_resource_owner_id"
    t.index ["token"], name: "index_oauth_access_tokens_on_token", unique: true
  end

  create_table "oauth_applications", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name", null: false
    t.string "uid", null: false
    t.string "secret", null: false
    t.text "redirect_uri", null: false
    t.string "scopes", default: "", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["uid"], name: "index_oauth_applications_on_uid", unique: true
  end

  create_table "order_activities", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "activitytime"
    t.bigint "order_id"
    t.bigint "user_id"
    t.text "action", size: :long, collation: "utf8mb4_unicode_ci"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "username"
    t.string "activity_type"
    t.boolean "acknowledged", default: false
    t.string "platform"
    t.index ["order_id"], name: "index_order_activities_on_order_id"
    t.index ["user_id"], name: "index_order_activities_on_user_id"
  end

  create_table "order_exceptions", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "reason"
    t.string "description"
    t.bigint "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "order_id"
    t.index ["order_id"], name: "index_order_exceptions_on_order_id"
    t.index ["user_id"], name: "index_order_exceptions_on_user_id"
  end

  create_table "order_import_summaries", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "user_id"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "import_summary_type", default: "import_orders"
    t.boolean "display_summary", default: false
  end

  create_table "order_item_boxes", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "box_id"
    t.integer "order_item_id"
    t.integer "item_qty"
    t.integer "kit_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "product_id"
  end

  create_table "order_item_kit_product_scan_times", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "scan_start"
    t.datetime "scan_end"
    t.integer "order_item_kit_product_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "order_item_kit_products", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "order_item_id"
    t.bigint "product_kit_skus_id"
    t.string "scanned_status", default: "unscanned"
    t.integer "scanned_qty", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "clicked_qty", default: 0
    t.index ["order_item_id"], name: "index_order_item_kit_products_on_order_item_id"
    t.index ["product_kit_skus_id"], name: "index_order_item_kit_products_on_product_kit_skus_id"
  end

  create_table "order_item_order_serial_product_lots", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "order_item_id"
    t.integer "product_lot_id"
    t.integer "order_serial_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "qty", default: 0
  end

  create_table "order_item_scan_times", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "scan_start"
    t.datetime "scan_end"
    t.integer "order_item_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "order_items", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "sku"
    t.integer "qty"
    t.decimal "price", precision: 10, scale: 2
    t.decimal "row_total", precision: 10
    t.bigint "order_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "name", size: :long, collation: "utf8mb4_unicode_ci"
    t.integer "product_id"
    t.string "scanned_status", default: "notscanned"
    t.integer "scanned_qty", default: 0
    t.boolean "kit_split", default: false
    t.integer "kit_split_qty", default: 0
    t.integer "kit_split_scanned_qty", default: 0
    t.integer "single_scanned_qty", default: 0
    t.string "inv_status", default: "unprocessed"
    t.string "inv_status_reason", default: ""
    t.integer "clicked_qty", default: 0
    t.boolean "is_barcode_printed", default: false
    t.boolean "is_deleted", default: false
    t.integer "box_id"
    t.integer "skipped_qty", default: 0
    t.integer "removed_qty", default: 0
    t.integer "added_count", default: 0
    t.index ["inv_status", "scanned_status"], name: "index_order_items_on_inv_status_and_scanned_status"
    t.index ["is_deleted"], name: "index_order_items_on_is_deleted"
    t.index ["order_id"], name: "index_order_items_on_order_id"
    t.index ["product_id"], name: "index_order_items_on_product_id"
    t.index ["qty"], name: "index_order_items_on_qty"
    t.index ["scanned_status"], name: "index_order_items_on_scanned_status"
  end

  create_table "order_serials", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "order_id"
    t.bigint "product_id"
    t.string "serial"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "second_serial"
    t.string "lot"
    t.datetime "exp_date"
    t.datetime "bestbuy_date"
    t.datetime "mfg_date"
    t.index ["order_id"], name: "index_order_serials_on_order_id"
    t.index ["product_id"], name: "index_order_serials_on_product_id"
  end

  create_table "order_shippings", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "firstname"
    t.string "lastname"
    t.string "email"
    t.string "streetaddress1"
    t.string "streetaddress2"
    t.string "city"
    t.string "region"
    t.string "postcode"
    t.string "country"
    t.string "description"
    t.bigint "order_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_order_shippings_on_order_id"
  end

  create_table "order_tags", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name", null: false
    t.string "color", default: "#B8B8B8", null: false
    t.string "mark_place", default: "0"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "predefined", default: false
    t.string "groovepacker_tag_origin"
    t.string "source_id"
    t.boolean "isVisible", default: true
  end

  create_table "order_tags_orders", id: false, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "order_id"
    t.integer "order_tag_id"
    t.index ["order_id", "order_tag_id"], name: "index_order_tags_orders_on_order_id_and_order_tag_id"
  end

  create_table "orders", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "increment_id"
    t.datetime "order_placed_time"
    t.string "sku"
    t.text "customer_comments", size: :long, collation: "utf8mb4_unicode_ci"
    t.integer "store_id"
    t.integer "qty"
    t.string "price"
    t.string "firstname", limit: 500, collation: "utf8mb4_unicode_ci"
    t.string "lastname", limit: 500, collation: "utf8mb4_unicode_ci"
    t.string "email"
    t.text "address_1"
    t.text "address_2"
    t.string "city", limit: 500, collation: "utf8mb4_unicode_ci"
    t.string "state"
    t.string "postcode"
    t.string "country"
    t.string "method"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "store_order_id"
    t.text "notes_internal"
    t.text "notes_toPacker"
    t.text "notes_fromPacker"
    t.boolean "tracking_processed"
    t.string "status"
    t.datetime "scanned_on"
    t.string "tracking_num"
    t.string "company"
    t.integer "packing_user_id"
    t.string "status_reason"
    t.string "order_number"
    t.integer "seller_id"
    t.integer "order_status_id"
    t.string "ship_name"
    t.decimal "shipping_amount", precision: 9, scale: 2, default: "0.0"
    t.decimal "order_total", precision: 9, scale: 2, default: "0.0"
    t.string "notes_from_buyer"
    t.integer "weight_oz"
    t.string "non_hyphen_increment_id"
    t.boolean "note_confirmation", default: false
    t.integer "inaccurate_scan_count", default: 0
    t.datetime "scan_start_time"
    t.boolean "reallocate_inventory", default: false
    t.datetime "last_suggested_at"
    t.integer "total_scan_time", default: 0
    t.integer "total_scan_count", default: 0
    t.decimal "packing_score", precision: 10, default: "0"
    t.string "custom_field_one"
    t.string "custom_field_two"
    t.boolean "traced_in_dashboard", default: false
    t.boolean "scanned_by_status_change", default: false
    t.string "shipment_id"
    t.boolean "already_scanned", default: false
    t.string "import_s3_key"
    t.datetime "last_modified"
    t.string "prime_order_id"
    t.text "split_from_order_id"
    t.text "source_order_ids"
    t.string "cloned_from_shipment_id", default: ""
    t.string "importer_id"
    t.integer "clicked_scanned_qty"
    t.string "import_item_id"
    t.string "job_timestamp"
    t.string "tags"
    t.string "post_scanning_flag"
    t.integer "origin_store_id"
    t.string "veeqo_allocation_id"
    t.integer "assigned_user_id"
    t.string "assigned_cart_tote_id"
    t.index ["assigned_cart_tote_id"], name: "index_orders_on_assigned_cart_tote_id"
    t.index ["id"], name: "index_orders_on_id"
    t.index ["increment_id"], name: "index_orders_on_increment_id"
    t.index ["non_hyphen_increment_id"], name: "index_orders_on_non_hyphen_increment_id"
    t.index ["scanned_on"], name: "index_orders_on_scanned_on"
    t.index ["status"], name: "index_orders_on_status"
    t.index ["store_id"], name: "index_orders_on_store_id"
    t.index ["tracking_num"], name: "index_orders_on_tracking_num"
  end

  create_table "origin_stores", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "store_id"
    t.integer "origin_store_id"
    t.string "recent_order_details", limit: 500, collation: "utf8mb4_unicode_ci"
    t.string "store_name", limit: 25
    t.index ["origin_store_id"], name: "index_origin_stores_on_origin_store_id"
    t.index ["store_id"], name: "index_origin_stores_on_store_id"
  end

  create_table "packing_cams", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "order_id", null: false
    t.bigint "order_item_id"
    t.bigint "user_id", null: false
    t.string "url"
    t.string "username"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_packing_cams_on_order_id"
    t.index ["order_item_id"], name: "index_packing_cams_on_order_item_id"
    t.index ["user_id"], name: "index_packing_cams_on_user_id"
  end

  create_table "print_pdf_links", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.text "url", size: :long
    t.boolean "is_pdf_printed", default: false
    t.string "pdf_name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "height"
    t.integer "width"
  end

  create_table "printing_settings", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "product_barcode_label_size", default: "3 x 1"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "priority_cards", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "priority_name", default: "regular", null: false
    t.string "assigned_tag", default: ""
    t.integer "order_tagged_count", default: 0
    t.string "tag_color", default: "#587493", null: false
    t.boolean "is_card_disabled", default: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.boolean "is_stand_by", default: false
    t.integer "position"
    t.datetime "oldest_order"
    t.boolean "is_favourite", default: false
    t.boolean "is_user_card", default: false
    t.index ["assigned_tag"], name: "index_priority_cards_on_assigned_tag", unique: true
    t.index ["priority_name"], name: "index_priority_cards_on_priority_name", unique: true
  end

  create_table "product_activities", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "activitytime"
    t.bigint "product_id"
    t.bigint "user_id"
    t.text "action", size: :long, collation: "utf8mb4_unicode_ci"
    t.string "username"
    t.string "activity_type"
    t.boolean "acknowledged", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_product_activities_on_product_id"
    t.index ["user_id"], name: "index_product_activities_on_user_id"
  end

  create_table "product_barcodes", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "product_id"
    t.string "barcode"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "order", default: 0
    t.string "lot_number"
    t.integer "packing_count", default: 1
    t.boolean "is_multipack_barcode", default: false
    t.index ["barcode"], name: "index_product_barcodes_on_barcode"
    t.index ["product_id"], name: "index_product_barcodes_on_product_id"
  end

  create_table "product_cats", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "category"
    t.bigint "product_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category"], name: "index_product_cats_on_category"
    t.index ["product_id"], name: "index_product_cats_on_product_id"
  end

  create_table "product_images", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "product_id"
    t.text "image"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "caption"
    t.integer "order", default: 0
    t.boolean "added_to_receiving_instructions", default: false
    t.string "image_note"
    t.boolean "placeholder", default: false
    t.index ["product_id"], name: "index_product_images_on_product_id"
  end

  create_table "product_inventory_reports", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name"
    t.boolean "scheduled", default: false
    t.boolean "type", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "is_locked", default: false
  end

  create_table "product_inventory_warehouses", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "location"
    t.integer "qty"
    t.bigint "product_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "alert"
    t.string "location_primary", limit: 50
    t.string "location_secondary", limit: 50
    t.string "name"
    t.integer "inventory_warehouse_id"
    t.integer "available_inv", default: 0, null: false
    t.integer "allocated_inv", default: 0, null: false
    t.string "location_tertiary", limit: 50
    t.integer "product_inv_alert_level", default: 0
    t.boolean "product_inv_alert", default: false
    t.integer "sold_inv", default: 0
    t.string "location_quaternary", limit: 50
    t.integer "location_primary_qty"
    t.integer "location_secondary_qty"
    t.integer "location_tertiary_qty"
    t.integer "location_quaternary_qty"
    t.integer "product_inv_target_level", default: 1
    t.index ["inventory_warehouse_id"], name: "index_product_inventory_warehouses_on_inventory_warehouse_id"
    t.index ["location_primary"], name: "index_product_inventory_warehouses_on_location_primary"
    t.index ["location_secondary"], name: "index_product_inventory_warehouses_on_location_secondary"
    t.index ["location_tertiary"], name: "index_product_inventory_warehouses_on_location_tertiary"
    t.index ["product_id"], name: "index_product_inventory_warehouses_on_product_id"
  end

  create_table "product_kit_activities", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "product_id"
    t.string "activity_message"
    t.string "username"
    t.string "activity_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "acknowledged", default: false
  end

  create_table "product_kit_skus", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "product_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "option_product_id"
    t.integer "qty", default: 0
    t.integer "packing_order", default: 50
    t.index ["product_id"], name: "index_product_kit_skus_on_product_id"
  end

  create_table "product_lots", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "product_id"
    t.string "lot_number"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_product_lots_on_product_id"
  end

  create_table "product_skus", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "sku"
    t.string "purpose"
    t.bigint "product_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "order", default: 0
    t.index ["product_id"], name: "index_product_skus_on_product_id"
    t.index ["sku"], name: "index_product_skus_on_sku"
  end

  create_table "products", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "store_product_id"
    t.text "name", size: :long, collation: "utf8mb4_unicode_ci"
    t.string "product_type"
    t.bigint "store_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "status", default: "new"
    t.string "packing_instructions", limit: 5000, collation: "utf8mb4_unicode_ci"
    t.boolean "packing_instructions_conf", default: false
    t.boolean "is_skippable", default: false
    t.integer "packing_placement", default: 50
    t.integer "pack_time_adj"
    t.string "kit_parsing", default: "individual"
    t.integer "is_kit", default: 0
    t.boolean "disable_conf_req", default: false
    t.integer "total_avail_ext", default: 0, null: false
    t.decimal "weight", precision: 8, scale: 2, default: "0.0", null: false
    t.decimal "shipping_weight", precision: 8, scale: 2, default: "0.0"
    t.boolean "record_serial", default: false
    t.string "type_scan_enabled", default: "on"
    t.string "click_scan_enabled", default: "on"
    t.string "weight_format"
    t.boolean "add_to_any_order", default: false
    t.string "base_sku"
    t.boolean "is_intangible", default: false
    t.text "product_receiving_instructions"
    t.boolean "status_updated", default: false
    t.boolean "is_inventory_product", default: false
    t.boolean "second_record_serial", default: false
    t.string "custom_product_1"
    t.string "custom_product_2"
    t.string "custom_product_3"
    t.boolean "custom_product_display_1", default: false
    t.boolean "custom_product_display_2", default: false
    t.boolean "custom_product_display_3", default: false
    t.string "fnsku"
    t.string "asin"
    t.string "fba_upc"
    t.string "isbn"
    t.string "ean"
    t.string "supplier_sku"
    t.decimal "avg_cost", precision: 10, scale: 2
    t.string "count_group", limit: 1
    t.integer "restock_lead_time", default: 0
    t.index ["name"], name: "index_products_on_name_255", length: 255
    t.index ["status"], name: "index_products_on_status"
    t.index ["store_id"], name: "index_products_on_store_id"
    t.index ["updated_at"], name: "index_products_on_updated_at"
  end

  create_table "products_product_inventory_reports", id: false, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "product_inventory_report_id"
    t.bigint "product_id"
  end

  create_table "request_logs", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "request_method"
    t.string "request_path"
    t.text "request_body", size: :long
    t.boolean "completed", default: false
    t.float "duration"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "roles", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name", null: false
    t.boolean "display", default: false, null: false
    t.boolean "custom", default: true, null: false
    t.boolean "add_edit_order_items", default: false, null: false
    t.boolean "import_orders", default: false, null: false
    t.boolean "change_order_status", default: false, null: false
    t.boolean "create_edit_notes", default: false, null: false
    t.boolean "view_packing_ex", default: false, null: false
    t.boolean "create_packing_ex", default: false, null: false
    t.boolean "edit_packing_ex", default: false, null: false
    t.boolean "delete_products", default: false, null: false
    t.boolean "import_products", default: false, null: false
    t.boolean "add_edit_products", default: false, null: false
    t.boolean "add_edit_users", default: false, null: false
    t.boolean "make_super_admin", default: false, null: false
    t.boolean "access_scanpack", default: true, null: false
    t.boolean "access_orders", default: false, null: false
    t.boolean "access_products", default: false, null: false
    t.boolean "access_settings", default: false, null: false
    t.boolean "edit_general_prefs", default: false, null: false
    t.boolean "edit_scanning_prefs", default: false, null: false
    t.boolean "add_edit_stores", default: false, null: false
    t.boolean "create_backups", default: false, null: false
    t.boolean "restore_backups", default: false, null: false
    t.boolean "edit_product_location", default: false, null: false
    t.boolean "edit_product_quantity", default: false, null: false
    t.boolean "edit_shipping_settings", default: false, null: false
    t.boolean "edit_visible_services", default: false, null: false
    t.boolean "add_edit_shortcuts", default: false, null: false
    t.boolean "add_edit_dimension_presets", default: false, null: false
  end

  create_table "scan_pack_settings", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.boolean "enable_click_sku", default: true
    t.boolean "ask_tracking_number", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "show_success_image", default: true
    t.string "success_image_src", default: "/assets/images/scan_success.png"
    t.float "success_image_time", default: 0.5
    t.boolean "show_fail_image", default: true
    t.string "fail_image_src", default: "/assets/images/scan_fail.png"
    t.float "fail_image_time", default: 1.0
    t.boolean "play_success_sound", default: true
    t.string "success_sound_url", default: "/assets/sounds/scan_success.mp3"
    t.float "success_sound_vol", default: 0.75
    t.boolean "play_fail_sound", default: true
    t.string "fail_sound_url", default: "/assets/sounds/scan_fail.mp3"
    t.float "fail_sound_vol", default: 0.75
    t.boolean "skip_code_enabled", default: true
    t.string "skip_code", default: "SKIP"
    t.boolean "note_from_packer_code_enabled", default: true
    t.string "note_from_packer_code", default: "NOTE"
    t.boolean "service_issue_code_enabled", default: true
    t.string "service_issue_code", default: "ISSUE"
    t.boolean "restart_code_enabled", default: true
    t.string "restart_code", default: "RESTART"
    t.boolean "show_order_complete_image", default: true
    t.string "order_complete_image_src", default: "/assets/images/scan_order_complete.png"
    t.float "order_complete_image_time", default: 1.0
    t.boolean "play_order_complete_sound", default: true
    t.string "order_complete_sound_url", default: "/assets/sounds/scan_order_complete.mp3"
    t.float "order_complete_sound_vol", default: 0.75
    t.boolean "type_scan_code_enabled", default: true
    t.string "type_scan_code", default: "*"
    t.string "post_scanning_option", default: "None"
    t.string "escape_string", default: " - "
    t.boolean "escape_string_enabled", default: false
    t.boolean "record_lot_number", default: false
    t.boolean "show_customer_notes", default: false
    t.boolean "show_internal_notes", default: false
    t.boolean "scan_by_shipping_label", default: false
    t.boolean "intangible_setting_enabled", default: false
    t.string "intangible_string", default: ""
    t.boolean "post_scan_pause_enabled", default: false
    t.float "post_scan_pause_time", default: 4.0
    t.boolean "intangible_setting_gen_barcode_from_sku", default: false
    t.boolean "display_location", default: false
    t.boolean "string_removal_enabled", default: false
    t.string "string_removal"
    t.boolean "first_escape_string_enabled", default: false
    t.boolean "second_escape_string_enabled", default: false
    t.string "second_escape_string"
    t.boolean "order_verification", default: false
    t.boolean "scan_by_packing_slip", default: true
    t.boolean "return_to_orders", default: false
    t.boolean "click_scan", default: false
    t.string "scanning_sequence", default: "any_sequence"
    t.string "click_scan_barcode", default: "CLICKSCAN"
    t.boolean "scanned", default: false
    t.string "scanned_barcode", default: "SCANNED"
    t.string "camera_option", default: "photo"
    t.string "packing_option", default: "after_packing"
    t.integer "resolution", default: 100
    t.string "post_scanning_option_second", default: "None"
    t.boolean "require_serial_lot", default: false
    t.string "valid_prefixes"
    t.boolean "replace_gp_code", default: false
    t.string "single_item_order_complete_msg", default: "Labels Printing!"
    t.float "single_item_order_complete_msg_time", default: 4.0
    t.string "multi_item_order_complete_msg", default: "Collect all items from the tote!"
    t.float "multi_item_order_complete_msg_time", default: 4.0
    t.string "tote_identifier", default: "Tote"
    t.boolean "show_expanded_shipments", default: true
    t.boolean "tracking_number_validation_enabled", default: false
    t.string "tracking_number_validation_prefixes"
    t.boolean "partial", default: false
    t.string "partial_barcode", default: "REMOVE-ALL"
    t.boolean "scan_by_packing_slip_or_shipping_label", default: false
    t.boolean "remove_enabled", default: false
    t.string "remove_barcode", default: "REMOVE"
    t.boolean "remove_skipped", default: true
    t.boolean "display_location2", default: false
    t.boolean "display_location3", default: false
    t.boolean "show_tags", default: false
    t.boolean "packing_cam_enabled", default: false
    t.boolean "email_customer_option", default: false
    t.text "email_subject"
    t.string "email_insert_dropdown", default: "order_number"
    t.text "email_message"
    t.string "email_logo"
    t.string "customer_page_dropdown", default: "order_number"
    t.text "customer_page_message"
    t.string "customer_page_logo"
    t.boolean "scanning_log", default: false
    t.boolean "pass_scan", default: true
    t.string "pass_scan_barcode", default: "PASS"
    t.boolean "add_next", default: true
    t.string "add_next_barcode", default: "ADDNEXT"
    t.boolean "send_external_logs", default: false
    t.boolean "scan_all_option", default: false
    t.string "capture_image_option", default: "automatic"
    t.string "email_reply"
    t.string "order_num_esc_str_removal", default: ""
    t.boolean "order_num_esc_str_enabled", default: false
    t.boolean "assigned_orders", default: false
    t.boolean "requires_assigned_orders", default: false
    t.boolean "enable_service_issue_status", default: true, null: false
    t.boolean "scan_to_cart_option", default: false
  end

  create_table "shipping_easy_credentials", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "store_id"
    t.string "api_key"
    t.string "api_secret"
    t.boolean "import_ready_for_shipment", default: false
    t.boolean "import_shipped", default: false
    t.boolean "gen_barcode_from_sku"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "last_imported_at"
    t.boolean "popup_shipping_label", default: false
    t.boolean "ready_to_ship", default: false
    t.string "store_api_key"
    t.boolean "import_upc", default: false
    t.boolean "allow_duplicate_id", default: true
    t.boolean "large_popup", default: true
    t.boolean "multiple_lines_per_sku_accepted", default: false
    t.boolean "use_alternate_id_as_order_num", default: false
    t.boolean "import_shipped_having_tracking", default: false
    t.boolean "remove_cancelled_orders", default: false
  end

  create_table "shipping_labels", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "order_id"
    t.bigint "shipment_id"
    t.text "url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
  end

  create_table "shippo_credentials", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "store_id"
    t.string "api_key"
    t.string "api_version"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "last_imported_at"
    t.string "generate_barcode_option", default: "do_not_generate"
    t.boolean "import_paid", default: false
    t.boolean "import_awaitpay", default: false
    t.boolean "import_partially_fulfilled", default: false
    t.boolean "import_shipped", default: false
    t.boolean "import_any", default: false
    t.boolean "import_shipped_having_tracking", default: false
  end

  create_table "shipstation_credentials", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "username", null: false
    t.string "password", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "store_id"
    t.datetime "last_imported_at"
  end

  create_table "shipstation_label_data", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.text "content", size: :long, collation: "utf8mb4_unicode_ci"
    t.bigint "order_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_shipstation_label_data_on_order_id"
  end

  create_table "shipstation_rest_credentials", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "api_key"
    t.string "api_secret"
    t.date "last_imported_at"
    t.integer "store_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "shall_import_awaiting_shipment", default: true
    t.boolean "shall_import_shipped", default: false
    t.boolean "warehouse_location_update", default: false
    t.boolean "shall_import_customer_notes", default: true
    t.boolean "shall_import_internal_notes", default: true
    t.integer "regular_import_range", default: 3
    t.boolean "gen_barcode_from_sku", default: false
    t.boolean "shall_import_pending_fulfillment", default: false
    t.datetime "quick_import_last_modified"
    t.boolean "use_chrome_extention", default: false
    t.boolean "switch_back_button", default: false
    t.boolean "auto_click_create_label", default: false
    t.boolean "download_ss_image", default: false
    t.boolean "return_to_order", default: false
    t.boolean "import_upc", default: false
    t.boolean "allow_duplicate_order", default: false
    t.boolean "tag_import_option", default: false
    t.boolean "bulk_import", default: false
    t.datetime "quick_import_last_modified_v2"
    t.integer "order_import_range_days", default: 30
    t.boolean "import_tracking_info", default: false
    t.datetime "last_location_push"
    t.boolean "use_api_create_label", default: false
    t.string "postcode", default: ""
    t.text "disabled_carriers"
    t.text "label_shortcuts"
    t.boolean "skip_ss_label_confirmation", default: false
    t.text "disabled_rates"
    t.boolean "add_gpscanned_tag", default: false
    t.boolean "remove_cancelled_orders", default: false
    t.text "contracted_carriers"
    t.text "presets"
    t.boolean "import_shipped_having_tracking", default: false
    t.boolean "import_discounts_option", default: false
    t.boolean "set_coupons_to_intangible", default: false
    t.string "full_name", default: ""
    t.string "street1", default: ""
    t.string "street2", default: ""
    t.string "city", default: ""
    t.string "state", default: ""
    t.string "country", default: ""
    t.string "webhook_secret", default: ""
    t.datetime "last_location_pull"
    t.integer "product_source_shopify_store_id"
    t.boolean "use_shopify_as_product_source_switch", default: false
  end

  create_table "shipworks_credentials", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "auth_token", null: false
    t.integer "store_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "shall_import_in_process", default: false
    t.boolean "shall_import_new_order", default: false
    t.boolean "shall_import_not_shipped", default: false
    t.boolean "shall_import_shipped", default: false
    t.boolean "shall_import_no_status", default: false
    t.boolean "import_store_order_number", default: false
    t.boolean "gen_barcode_from_sku", default: false
    t.boolean "shall_import_ignore_local", default: false
  end

  create_table "shopify_credentials", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "shop_name"
    t.string "access_token"
    t.integer "store_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "last_imported_at"
    t.string "shopify_status", default: "open"
    t.boolean "shipped_status", default: false
    t.boolean "unshipped_status", default: false
    t.boolean "partial_status", default: false
    t.datetime "product_last_import"
    t.string "modified_barcode_handling", default: "add_to_existing"
    t.string "generating_barcodes", default: "do_not_generate"
    t.boolean "import_inventory_qoh", default: false
    t.boolean "import_updated_sku", default: false
    t.string "updated_sku_handling", default: "add_to_existing"
    t.boolean "permit_shared_barcodes", default: false
    t.boolean "fix_all_product_images", default: false
    t.boolean "import_fulfilled_having_tracking", default: false
    t.text "temp_cookies", size: :long
    t.boolean "add_gp_scanned_tag", default: false
    t.boolean "on_hold_status", default: false
    t.string "re_associate_shopify_products", default: "associate_items"
    t.boolean "import_variant_names", default: false
    t.boolean "webhook_order_import", default: false
    t.bigint "push_inv_location_id"
    t.bigint "pull_inv_location_id"
    t.boolean "pull_combined_qoh", default: false
    t.integer "order_import_range_days", default: 30
    t.boolean "open_shopify_create_shipping_label", default: false
    t.boolean "mark_shopify_order_fulfilled", default: false
  end

  create_table "shopline_credentials", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "shop_name"
    t.text "access_token"
    t.integer "store_id"
    t.datetime "last_imported_at"
    t.string "shopline_status", default: "open"
    t.boolean "import_inventory_qoh", default: false
    t.boolean "import_updated_sku", default: false
    t.string "updated_sku_handling", default: "add_to_existing"
    t.string "generating_barcodes", default: "do_not_generate"
    t.string "modified_barcode_handling", default: "add_to_existing"
    t.boolean "shipped_status", default: false
    t.boolean "unshipped_status", default: false
    t.boolean "on_hold_status", default: false
    t.boolean "partial_status", default: false
    t.boolean "import_fulfilled_having_tracking", default: false
    t.boolean "import_variant_names", default: false
    t.bigint "push_inv_location_id"
    t.bigint "pull_inv_location_id"
    t.boolean "pull_combined_qoh", default: false
    t.boolean "fix_all_product_images", default: false
    t.datetime "product_last_import"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "permit_shared_barcodes", default: false
  end

  create_table "store_product_imports", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "status"
    t.integer "success_imported", default: 0
    t.integer "success_updated", default: 0
    t.integer "total", default: 0
    t.integer "store_id"
    t.string "current_sku"
    t.integer "delayed_job_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "stores", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name", null: false
    t.boolean "status", default: false, null: false
    t.string "store_type", null: false
    t.date "order_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "inventory_warehouse_id"
    t.text "thank_you_message_to_customer"
    t.boolean "auto_update_products", default: false
    t.boolean "update_inv", default: false
    t.boolean "on_demand_import", default: false
    t.boolean "fba_import", default: false
    t.boolean "csv_beta", default: true
    t.boolean "is_verify_separately"
    t.string "split_order", default: "disabled"
    t.boolean "on_demand_import_v2", default: false
    t.boolean "regular_import_v2", default: false
    t.boolean "quick_fix", default: false
    t.boolean "troubleshooter_option", default: true
    t.boolean "order_cup_direct_shipping", default: false
    t.boolean "display_origin_store_name", default: false
    t.boolean "disable_packing_cam", default: false
    t.boolean "import_user_assignments", default: false
    t.index ["name"], name: "index_stores_on_name"
  end

  create_table "stripe_webhooks", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.binary "event", size: :medium
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "subscriptions", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "email"
    t.string "tenant_name"
    t.decimal "amount", precision: 8, scale: 2, default: "0.0"
    t.string "stripe_user_token"
    t.string "status"
    t.integer "tenant_id"
    t.string "stripe_transaction_identifier"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "transaction_errors"
    t.string "subscription_plan_id"
    t.string "customer_subscription_id"
    t.string "stripe_customer_id"
    t.boolean "is_active"
    t.string "password", null: false
    t.string "user_name", null: false
    t.string "coupon_id"
    t.string "progress", default: "not_started"
    t.boolean "shopify_customer", default: false
    t.boolean "all_charges_paid", default: false
    t.string "interval"
    t.string "app_charge_id"
    t.string "tenant_charge_id"
    t.string "shopify_shop_name"
    t.text "tenant_data"
    t.string "shopify_payment_token"
  end

  create_table "sync_options", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "product_id"
    t.boolean "sync_with_bc", default: false
    t.integer "bc_product_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "bc_product_sku"
    t.boolean "sync_with_mg_rest"
    t.integer "mg_rest_product_id"
    t.boolean "sync_with_shopify", default: false
    t.string "shopify_product_variant_id"
    t.string "mg_rest_product_sku"
    t.boolean "sync_with_teapplix", default: false
    t.string "teapplix_product_sku"
    t.string "shopify_inventory_item_id"
    t.boolean "sync_with_shopline", default: false
    t.string "shopline_product_variant_id"
    t.string "shopline_inventory_item_id"
  end

  create_table "teapplix_credentials", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "store_id"
    t.string "account_name"
    t.string "username"
    t.string "password"
    t.boolean "import_shipped", default: false
    t.boolean "import_open_orders", default: false
    t.datetime "last_imported_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "gen_barcode_from_sku", default: false
    t.boolean "import_shipped_having_tracking", default: false
  end

  create_table "tenants", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "duplicate_tenant_id"
    t.text "note"
    t.boolean "is_modified", default: false
    t.string "initial_plan_id"
    t.text "addon_notes"
    t.boolean "magento_tracking_push_enabled", default: false
    t.integer "orders_delete_days", default: 14, null: false
    t.boolean "scheduled_import_toggle", default: false
    t.boolean "is_fba", default: false
    t.boolean "inventory_report_toggle", default: false
    t.boolean "is_multi_box", default: false
    t.boolean "api_call", default: false
    t.boolean "allow_rts", default: false
    t.text "activity_log"
    t.boolean "test_tenant_toggle", default: false
    t.boolean "product_activity_switch", default: true
    t.datetime "last_charge_in_stripe"
    t.boolean "packing_cam", default: false
    t.boolean "custom_product_fields", default: true
    t.text "price"
    t.boolean "groovelytic_stat", default: false
    t.boolean "is_delay", default: false
    t.boolean "product_ftp_import", default: false
    t.string "scan_pack_workflow", default: "default"
    t.string "last_import_store_type"
    t.boolean "store_order_respose_log", default: false
    t.boolean "delayed_inventory_update", default: false
    t.boolean "daily_packed_toggle", default: false
    t.boolean "is_cf", default: true
    t.boolean "ss_api_create_label", default: true
    t.boolean "direct_printing_options", default: true
    t.boolean "expo_logs_delay", default: false
    t.boolean "gdpr_shipstation", default: false
    t.boolean "uniq_shopify_import", default: false
    t.boolean "order_cup_direct_shipping", default: false
    t.boolean "show_external_logs_button", default: false
    t.boolean "loggly_sw_imports", default: false
    t.boolean "show_originating_store_id", default: false
    t.boolean "enable_developer_tools", default: false
    t.boolean "loggly_shopify_imports", default: false
    t.boolean "loggly_se_imports", default: false
    t.boolean "loggly_gpx_order_scan", default: false
    t.boolean "loggly_shipstation_imports", default: false
    t.text "settings"
    t.boolean "loggly_veeqo_imports", default: false
    t.boolean "voice_packing", default: false
    t.boolean "scan_to_score", default: false
  end

  create_table "tote_sets", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "max_totes", default: 40
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "totes", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name"
    t.integer "number"
    t.bigint "order_id"
    t.bigint "tote_set_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "pending_order", default: false
    t.index ["order_id"], name: "index_totes_on_order_id"
    t.index ["tote_set_id"], name: "index_totes_on_tote_set_id"
  end

  create_table "transactions", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "transaction_id"
    t.decimal "amount", precision: 8, scale: 2, default: "0.0"
    t.string "card_type"
    t.integer "exp_month_of_card"
    t.integer "exp_year_of_card"
    t.datetime "date_of_payment"
    t.integer "subscription_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "uniq_job_tables", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "worker_id"
    t.string "job_timestamp"
    t.string "job_id"
    t.bigint "job_count", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "user_inventory_permissions", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "inventory_warehouse_id", null: false
    t.boolean "see", default: false, null: false
    t.boolean "edit", default: false, null: false
    t.index ["inventory_warehouse_id"], name: "index_user_inventory_permissions_on_inventory_warehouse_id"
    t.index ["user_id", "inventory_warehouse_id"], name: "index_user_inventory_permissions_user_inventory", unique: true
    t.index ["user_id"], name: "index_user_inventory_permissions_on_user_id"
  end

  create_table "users", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "username", default: "", null: false
    t.boolean "active", default: false, null: false
    t.string "other"
    t.string "name"
    t.string "confirmation_code", default: "", null: false
    t.integer "inventory_warehouse_id"
    t.integer "role_id"
    t.string "view_dashboard", default: "none"
    t.boolean "is_deleted", default: false
    t.string "reset_token"
    t.string "email"
    t.string "last_name"
    t.string "custom_field_one"
    t.string "custom_field_two"
    t.boolean "dashboard_switch", default: false
    t.string "warehouse_postcode", default: ""
    t.string "packing_slip_size", default: "4 x 6"
    t.boolean "override_pass_scanning", default: false
    t.datetime "last_purchased_at"
    t.integer "last_purchased_by"
    t.integer "total_purchases"
    t.string "token"
    t.json "sound_selected_types"
    t.index ["inventory_warehouse_id"], name: "index_users_on_inventory_warehouse_id"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["role_id"], name: "index_users_on_role_id"
    t.index ["token"], name: "index_users_on_token", unique: true
  end

  create_table "veeqo_credentials", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "api_key"
    t.integer "store_id"
    t.datetime "last_imported_at"
    t.boolean "shipped_status", default: false
    t.boolean "awaiting_amazon_fulfillment_status", default: false
    t.boolean "awaiting_fulfillment_status", default: false
    t.boolean "import_shipped_having_tracking", default: false
    t.boolean "gen_barcode_from_sku", default: false
    t.boolean "allow_duplicate_order", default: false
    t.boolean "shall_import_internal_notes", default: false
    t.boolean "shall_import_customer_notes", default: false
    t.integer "order_import_range_days", default: 30
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "import_tracking_info", default: true
    t.boolean "remove_cancelled_orders", default: true
    t.boolean "import_upc", default: true
    t.boolean "set_coupons_to_intangible", default: true
    t.integer "product_source_shopify_store_id"
    t.boolean "use_shopify_as_product_source_switch", default: false
    t.boolean "use_veeqo_order_id", default: false
  end

  create_table "visits", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "visit_token"
    t.string "visitor_token"
    t.string "ip"
    t.text "user_agent"
    t.text "referrer"
    t.text "landing_page"
    t.integer "user_id"
    t.string "referring_domain"
    t.string "search_keyword"
    t.string "browser"
    t.string "os"
    t.string "device_type"
    t.integer "screen_height"
    t.integer "screen_width"
    t.string "country"
    t.string "region"
    t.string "city"
    t.string "postal_code"
    t.decimal "latitude", precision: 10
    t.decimal "longitude", precision: 10
    t.string "utm_source"
    t.string "utm_medium"
    t.string "utm_term"
    t.string "utm_content"
    t.string "utm_campaign"
    t.timestamp "started_at"
    t.index ["user_id"], name: "index_visits_on_user_id"
    t.index ["visit_token"], name: "index_visits_on_visit_token", unique: true
  end

  add_foreign_key "cart_rows", "carts"
end
