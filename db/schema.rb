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

ActiveRecord::Schema.define(:version => 20130908132106) do

  create_table "amazon_credentials", :force => true do |t|
    t.string   "access_key_id",                               :null => false
    t.string   "secret_access_key",                           :null => false
    t.string   "app_name",                                    :null => false
    t.string   "app_version",                                 :null => false
    t.string   "merchant_id",                                 :null => false
    t.string   "marketplace_id",                              :null => false
    t.integer  "store_id"
    t.datetime "created_at",                                  :null => false
    t.datetime "updated_at",                                  :null => false
    t.string   "productaccess_key_id",     :default => "",    :null => false
    t.string   "productsecret_access_key", :default => "",    :null => false
    t.string   "productapp_name",          :default => "",    :null => false
    t.string   "productapp_version",       :default => "",    :null => false
    t.string   "productmerchant_id",       :default => "",    :null => false
    t.string   "productmarketplace_id",    :default => "",    :null => false
    t.boolean  "import_products",          :default => false, :null => false
    t.boolean  "import_images",            :default => false, :null => false
  end

  create_table "ebay_credentials", :force => true do |t|
    t.string   "dev_id",                               :null => false
    t.string   "app_id",                               :null => false
    t.string   "cert_id",                              :null => false
    t.integer  "store_id"
    t.datetime "created_at",                           :null => false
    t.datetime "updated_at",                           :null => false
    t.string   "productdev_id",     :default => "",    :null => false
    t.string   "productapp_id",     :default => "",    :null => false
    t.string   "productcert_id",    :default => "",    :null => false
    t.boolean  "import_products",   :default => false, :null => false
    t.boolean  "import_images",     :default => false, :null => false
    t.text     "auth_token",                           :null => false
    t.text     "productauth_token",                    :null => false
  end

  create_table "magento_credentials", :force => true do |t|
    t.string   "host",                               :null => false
    t.string   "username",                           :null => false
    t.string   "password",                           :null => false
    t.integer  "store_id",                           :null => false
    t.datetime "created_at",                         :null => false
    t.datetime "updated_at",                         :null => false
    t.string   "api_key",         :default => "",    :null => false
    t.string   "producthost",     :default => "",    :null => false
    t.string   "productusername", :default => "",    :null => false
    t.string   "productpassword", :default => "",    :null => false
    t.string   "productapi_key",  :default => "",    :null => false
    t.boolean  "import_products", :default => false, :null => false
    t.boolean  "import_images",   :default => false, :null => false
  end

  create_table "product_cats", :force => true do |t|
    t.string   "category"
    t.integer  "product_id"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  add_index "product_cats", ["product_id"], :name => "index_product_cats_on_product_id"

  create_table "product_skus", :force => true do |t|
    t.string   "sku"
    t.string   "purpose"
    t.integer  "product_id"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  add_index "product_skus", ["product_id"], :name => "index_product_skus_on_product_id"

  create_table "products", :force => true do |t|
    t.string   "store_product_id", :null => false
    t.string   "name",             :null => false
    t.string   "product_type"
    t.integer  "store_id",         :null => false
    t.datetime "created_at",       :null => false
    t.datetime "updated_at",       :null => false
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
  end

  add_index "users", ["reset_password_token"], :name => "index_users_on_reset_password_token", :unique => true

  create_table "users_roles", :id => false, :force => true do |t|
    t.integer "user_id"
    t.integer "role_id"
  end

  add_index "users_roles", ["user_id", "role_id"], :name => "index_users_roles_on_user_id_and_role_id"

end
