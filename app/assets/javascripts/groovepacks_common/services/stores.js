groovepacks_services.factory('stores', ['$http', 'notification', '$filter', function ($http, notification, $filter) {

  /**
   * @typedef {object} StoresHash
   * @property {array} list - list of stores.
   * @property {object} single - hash of a single store data.
   * @property {object} ebay - hash of ebay settings.
   * @property {object} import - hash of import settings.
   * @property {object} types - hash of supported store types.
   * @property {number} current - index of currently open store in list.
   * @property {object} setup - settings of stores list setup.
   */

  var success_messages = {
    update_status: "Status updated Successfully",
    delete: "Deleted Successfully",
    duplicate: "Duplicated Successfully"
  };

  var get_default = function () {
    return {
      list: [],
      single: {},
      ebay: {},
      csv: {
        mapping: {},
        maps: {
          order: [],
          product: []
        }
      },
      import: {
        order: {},
        product: {}
      },
      update: {
        products: {}
      },
      types: {},
      current: 0,
      setup: {
        sort: "",
        order: "DESC",
        search: '',
        select_all: false,
        //used for updating only
        status: '',
        storeArray: []
      }
    };
  };

   var select_notification = function () {
    notification.notify("Please select atleast one Store", 0);
  }

  //Setup related function
  var update_setup = function (setup, type, value) {
    if (type == 'sort') {
      if (setup[type] == value) {
        if (setup.order == "DESC") {
          setup.order = "ASC";
        } else {
          setup.order = "DESC";
        }
      } else {
        setup.order = "DESC";
      }
    }
    setup[type] = value;
    return setup;
  };

  //list related functions
  var get_list = function (object) {
    var result = [];
    return $http.get('/stores.json').success(
      function (data) {
        result = $filter('filter')(data, object.setup.search);
        result = $filter('orderBy')(result, object.setup.sort, (object.setup.order == 'DESC'));
        object.list = result;
      }
    ).error(notification.server_error);
  };

  var update_list = function (action, stores) {
    if (["update_status", "delete", "duplicate"].indexOf(action) != -1) {
      stores.setup.storeArray = [];
      for (var i = 0; i < stores.list.length; i++) {
        if (stores.list[i].checked == true) {
          stores.setup.storeArray.push({id: stores.list[i].id, status: (stores.setup.status == 'active')});
        }
      }
      var url = '';
      if (action == "delete") {
        url = '/stores/delete_store.json';
      } else if (action == "duplicate") {
        url = '/stores/duplicate_store.json';
      } else if (action == "update_status") {
        url = '/stores/change_store_status.json';
      }

      return $http.post(url, stores.setup.storeArray).success(function (data) {
        if (data.status) {
          stores.setup.select_all = false;
          notification.notify(success_messages[action], 1);
        } else {
          notification.notify(data.messages, 0);
        }
      }).error(notification.server_error);
    }
  };

  var update_list_node = function (obj) {
    return $http.post('/stores/update_store_list.json', obj).success(function (data) {
      if (data.status) {
        notification.notify("Successfully Updated", 1);
      } else {
        notification.notify(data.error_msg, 0);
      }
    }).error(notification.server_error);
  };

  var amazon_products_import = function (obj) {
    return $http({
                  method: 'POST',
                  headers: {'Content-Type': undefined},
                  url: '/amazons/products_import.json',
                  transformRequest: function (obj) {
                    var request = new FormData();
                    for (var key in obj) {
                      if (obj.hasOwnProperty(key)) {
                        request.append(key, obj[key]);
                      }
                    }
                    return request;
                  },
                  data: obj
                }).success(function (data) {
                  if (data.status) {
                    notification.notify("Your request has been queued successfully", 1);
                  } else {
                    notification.notify(data.messages, 0);
                  }
                }).error(notification.server_error);
  };



  //single store related functions
  var get_single = function (id, stores) {
    return $http.get('/stores/'+id+'.json').success(function (data) {
      // stores.single = {};
      stores.import.product.status = "";
      stores.import.order.status = "";
      stores.import.product.status_show = false;
      stores.import.order.status_show = false;
      if (data.status) {
        // stores.single = data.store;
        for (var key in data.store) {
          stores.single[key] = data.store[key];
        }
        if (data.mapping) {
          stores.csv.mapping = data.mapping;
        }
        if (data.credentials.status == true) {
          stores.single.allow_bc_inv_push = data.access_restrictions.allow_bc_inv_push;
          stores.single.allow_mg_rest_inv_push = data.access_restrictions.allow_mg_rest_inv_push;
          stores.single.allow_shopify_inv_push = data.access_restrictions.allow_shopify_inv_push;
          stores.single.allow_teapplix_inv_push = data.access_restrictions.allow_teapplix_inv_push;
          stores.single.allow_magento_soap_tracking_no_push = data.access_restrictions.allow_magento_soap_tracking_no_push;
          stores.general_settings = data.general_settings;
          stores.current_tenant = data.current_tenant;
          stores.host_url = data.host_url;
          if (data.store.store_type == 'Magento') {
            stores.single.host = data.credentials.magento_credentials.host;
            stores.single.username = data.credentials.magento_credentials.username;
            stores.single.password = data.credentials.magento_credentials.password;
            stores.single.api_key = data.credentials.magento_credentials.api_key;

            stores.single.shall_import_processing = data.credentials.magento_credentials.shall_import_processing;
            stores.single.shall_import_pending = data.credentials.magento_credentials.shall_import_pending;
            stores.single.shall_import_closed = data.credentials.magento_credentials.shall_import_closed;
            stores.single.shall_import_complete = data.credentials.magento_credentials.shall_import_complete;
            stores.single.shall_import_fraud = data.credentials.magento_credentials.shall_import_fraud;
            stores.single.enable_status_update = data.credentials.magento_credentials.enable_status_update;
            stores.single.status_to_update = data.credentials.magento_credentials.status_to_update;
            stores.single.push_tracking_number = data.credentials.magento_credentials.push_tracking_number;

            stores.single.producthost = data.credentials.magento_credentials.producthost;
            stores.single.productusername = data.credentials.magento_credentials.productusername;
            stores.single.productpassword = data.credentials.magento_credentials.productpassword;
            stores.single.productapi_key = data.credentials.magento_credentials.productapi_key;
            stores.single.import_products = data.credentials.magento_credentials.import_products;
            stores.single.import_images = data.credentials.magento_credentials.import_images;

          } else if (data.store.store_type == 'Magento API 2') {
            stores.single.store_version = data.credentials.magento_rest_credential.store_version;
            stores.single.store_token = data.credentials.magento_rest_credential.store_token;
            stores.single.host = data.credentials.magento_rest_credential.host;
            stores.single.store_admin_url = data.credentials.magento_rest_credential.store_admin_url;
            stores.single.api_key = data.credentials.magento_rest_credential.api_key;
            stores.single.api_secret = data.credentials.magento_rest_credential.api_secret;
            stores.single.access_token = data.credentials.magento_rest_credential.access_token;
            stores.single.oauth_token_secret = data.credentials.magento_rest_credential.oauth_token_secret;
            stores.single.import_images = data.credentials.magento_rest_credential.import_images;
            stores.single.import_categories = data.credentials.magento_rest_credential.import_categories;
            stores.single.gen_barcode_from_sku = data.credentials.magento_rest_credential.gen_barcode_from_sku;

          } else if (data.store.store_type == 'ShippingEasy') {
            stores.single.include_product = data.credentials.shipping_easy_credentials.includes_product;
            stores.single.popup_shipping_label = data.credentials.shipping_easy_credentials.popup_shipping_label;
            stores.single.api_key = data.credentials.shipping_easy_credentials.api_key;
            stores.single.api_secret = data.credentials.shipping_easy_credentials.api_secret;
            stores.single.import_ready_for_shipment = data.credentials.shipping_easy_credentials.import_ready_for_shipment;
            stores.single.import_shipped = data.credentials.shipping_easy_credentials.import_shipped;
            stores.single.gen_barcode_from_sku = data.credentials.shipping_easy_credentials.gen_barcode_from_sku;

          } else if (data.store.store_type == 'Ebay') {
            stores.single.ebay_auth_token = data.credentials.ebay_credentials.auth_token;
            stores.single.productebay_auth_token = data.credentials.ebay_credentials.productauth_token;
            stores.single.import_products = data.credentials.ebay_credentials.import_products;
            stores.single.import_images = data.credentials.ebay_credentials.import_images;
            if (stores.single.ebay_auth_token != '' && stores.single.ebay_auth_token != null) {
              stores.ebay.show_url = false;
            } else {
              stores.ebay.show_url = true;
              ebay_sign_in_url(stores);
            }

          } else if (data.store.store_type == 'Amazon') {
            stores.single.marketplace_id = data.credentials.amazon_credentials.marketplace_id;
            stores.single.merchant_id = data.credentials.amazon_credentials.merchant_id;
            stores.single.mws_auth_token = data.credentials.amazon_credentials.mws_auth_token;

            stores.single.productmarketplace_id = data.credentials.amazon_credentials.productmarketplace_id;
            stores.single.productmerchant_id = data.credentials.amazon_credentials.productmerchant_id;
            stores.single.import_products = data.credentials.amazon_credentials.import_products;
            stores.single.import_images = data.credentials.amazon_credentials.import_images;
            stores.single.show_shipping_weight_only = data.credentials.amazon_credentials.show_shipping_weight_only;
            stores.single.productreport_id = data.credentials.amazon_credentials.productreport_id;
            stores.single.productgenerated_report_id = data.credentials.amazon_credentials.productgenerated_report_id
          } else if (data.store.store_type == 'Shipstation') {
            stores.single.username = data.credentials.shipstation_credentials.username;
            stores.single.password = data.credentials.shipstation_credentials.password;
          } else if (data.store.store_type == 'Shipstation API 2') {
            stores.single.use_chrome_extention = data.credentials.shipstation_rest_credentials.use_chrome_extention;
            stores.single.switch_back_button = data.credentials.shipstation_rest_credentials.switch_back_button;
            stores.single.auto_click_create_label = data.credentials.shipstation_rest_credentials.auto_click_create_label;
            stores.single.api_key = data.credentials.shipstation_rest_credentials.api_key;
            stores.single.api_secret = data.credentials.shipstation_rest_credentials.api_secret;
            stores.single.shall_import_awaiting_shipment = data.credentials.shipstation_rest_credentials.shall_import_awaiting_shipment;
            stores.single.shall_import_shipped = data.credentials.shipstation_rest_credentials.shall_import_shipped;
            stores.single.shall_import_pending_fulfillment = data.credentials.shipstation_rest_credentials.shall_import_pending_fulfillment;
            stores.single.shall_import_customer_notes =
              data.credentials.shipstation_rest_credentials.shall_import_customer_notes;
            stores.single.shall_import_internal_notes =
              data.credentials.shipstation_rest_credentials.shall_import_internal_notes;
            stores.single.regular_import_range =
              data.credentials.shipstation_rest_credentials.regular_import_range;
            stores.single.import_days = ["0", "1", "2", "3", "4", "5", "6"];
            stores.single.warehouse_location_update = data.credentials.shipstation_rest_credentials.warehouse_location_update;
            stores.single.gp_ready_tag_name = data.credentials.shipstation_rest_credentials.gp_ready_tag_name;
            stores.single.gp_imported_tag_name = data.credentials.shipstation_rest_credentials.gp_imported_tag_name;
            stores.single.gen_barcode_from_sku = data.credentials.shipstation_rest_credentials.gen_barcode_from_sku;
            //shall_import_customer_notes
          } else if (data.store.store_type == 'Shipworks') {
            stores.single.auth_token = data.credentials.shipworks_credentials.auth_token;
            stores.single.import_store_order_number = data.credentials.shipworks_credentials.import_store_order_number
            stores.single.shall_import_in_process = data.credentials.shipworks_credentials.shall_import_in_process;
            stores.single.shall_import_new_order = data.credentials.shipworks_credentials.shall_import_new_order;
            stores.single.shall_import_not_shipped = data.credentials.shipworks_credentials.shall_import_not_shipped;
            stores.single.shall_import_shipped = data.credentials.shipworks_credentials.shall_import_shipped;
            stores.single.shall_import_no_status = data.credentials.shipworks_credentials.shall_import_no_status;
            stores.single.gen_barcode_from_sku = data.credentials.shipworks_credentials.gen_barcode_from_sku;
            stores.single.request_url = data.credentials.shipworks_hook_url;
          } else if (data.store.store_type == 'Shopify') {
            stores.single.shop_name = data.credentials.shopify_credentials.shop_name;
            stores.single.access_token = data.credentials.shopify_credentials.access_token;
            stores.single.shopify_permission_url = data.credentials.shopify_permission_url;
          }else if (data.store.store_type == 'BigCommerce') {
            stores.single.shop_name = data.credentials.big_commerce_credentials.shop_name;
            stores.single.access_token = data.credentials.big_commerce_credentials.access_token;
            stores.single.store_hash = data.credentials.big_commerce_credentials.store_hash;
            stores.single.bigcommerce_permission_url = data.credentials.bigcommerce_permission_url;
          }else if (data.store.store_type == 'Teapplix') {
            stores.single.account_name = data.credentials.teapplix_credential.account_name;
            stores.single.username = data.credentials.teapplix_credential.username;
            stores.single.password = data.credentials.teapplix_credential.password;
            stores.single.gen_barcode_from_sku = data.credentials.teapplix_credential.gen_barcode_from_sku;
            stores.single.import_shipped = data.credentials.teapplix_credential.import_shipped;
            stores.single.import_open_orders = data.credentials.teapplix_credential.import_open_orders;
          } else if (data.store.store_type == 'CSV') {
            stores.single.host = data.credentials.ftp_credentials.host;
            stores.single.port = data.credentials.ftp_credentials.port;
            stores.single.connection_method = data.credentials.ftp_credentials.connection_method;
            stores.single.connection_established = data.credentials.ftp_credentials.connection_established;
            stores.single.username = data.credentials.ftp_credentials.username;
            stores.single.password = data.credentials.ftp_credentials.password;
            stores.single.use_ftp_import = data.credentials.ftp_credentials.use_ftp_import;
          }
        }
      }
    }).error(notification.server_error);
  };
  var get_system = function (stores) {
    return $http.get('/stores/get_system.json').success(function (data) {
      if (data.status) {
        stores.single = data.store;
      }
    }).error(notification.server_error);
  };

  /**
   * Validate if we have all the data to send a store creation request.
   * @param {StoresHash} stores - {@link StoresHash}
   * @returns {boolean} true if the code can proceed to create a store.
   */
  var validate_create_single = function (stores) {
    //Return true if the checks match, if it reaches the end it returns false by default.
    if (stores.single.name && stores.single.store_type) {
      switch (stores.single.store_type) {
        case 'Magento':
          return (stores.single.host && stores.single.username && stores.single.api_key);
          break;
        case 'Shipstation':
          return (stores.single.username && stores.single.password);
          break;
        case 'Shipstation API 2':
          return (stores.single.api_key && stores.single.api_secret);
          break;
        case 'Amazon':
          return (stores.single.merchant_id && stores.single.marketplace_id);
          break;
        case 'Shopify':
          return (stores.single.shop_name);
          break;
        //for any other store types (ebay and csv) just return true
        case 'Shipworks':
        default:
          return true;
      }
    }
    return false;
  };

  var validate_not_empty = function () {

  }

  var can_create_single = function () {
    return $http.get('/stores/let_store_be_created.json')
  };

  var create_update_single = function (stores, auto) {
    if (typeof auto !== "boolean") {
      auto = true;
    }
    return $http({
      method: 'POST',
      headers: {'Content-Type': undefined},
      url: '/stores/create_update_store.json',
      transformRequest: function (data) {
        var request = new FormData();
        for (var key in data) {
          if (data.hasOwnProperty(key)) {
            request.append(key, data[key]);
          }
        }
        return request;
      },
      data: stores.single
    }).success(function (data) {
      if (data.status && data.store_id) {
        if (!auto) {
          if (data.csv_import) {
            notification.notify("Successfully Updated", 1);
          }
          ;
        }
      } else {
        notification.notify(data.messages, 0);
      }
    }).error(notification.server_error);
  };

  var connect_ftp_server = function(stores) {
    return $http.get('/stores/'+stores.single.id+'/connect_and_retrieve.json').success(function (data) {
      if (data.connection.status) {
        notification.notify(data.connection.success_messages, 1);
        stores.single.file_path = data.connection.downloaded_file;
      } else {
        notification.notify(data.connection.error_messages, 0);
      }
    }).error(notification.server_error);
  };

  var create_update_ftp_credentials = function(stores) {
    return $http({
      method: 'POST',
      headers: {'Content-Type': undefined},
      url: '/stores/'+stores.single.id+'/create_update_ftp_credentials.json',
      transformRequest: function (data) {
        var request = new FormData();
        for (var key in data) {
          if (data.hasOwnProperty(key)) {
            request.append(key, data[key]);
          }
        }
        return request;
      },
      data: stores.single
    }).success(function(data) {
      if(data.status) {
        notification.notify("Successfully Updated", 1);
      } else {
        notification.notify(data.messages, 0);
      }
    }).error(notification.server_error);
  }

  //ebay related functions
  var ebay_sign_in_url = function (stores) {
    return $http.get('/stores/get_ebay_signin_url.json').success(function (data) {
      if (data.ebay_signin_url_status) {
        stores.ebay.signin_url = data.ebay_signin_url;
        stores.ebay.signin_url_status = data.ebay_signin_url_status;
        stores.ebay.sessionid = data.ebay_sessionid;
        stores.ebay.current_tenant = data.current_tenant;
      }
    }).error(function (data) {
      stores.ebay.signin_url_status = false;
      notification.server_error(data);
    });
  };

  var ebay_token_fetch = function (stores) {
    return $http.get('/stores/ebay_user_fetch_token.json').success(function (data) {
      if (data.status) {
        stores.ebay.show_url = false;
      }
    }).error(notification.server_error);
  };

  var ebay_token_delete = function (stores) {
    return $http.post('/stores/'+stores.single.id+'/delete_ebay_token.json').success(function (data) {
      if (data.status) {
        ebay_sign_in_url(stores);
      }
    }).error(notification.server_error);
  };

  var ebay_token_update = function (stores, id) {
    return $http.post('/stores/'+id+'/update_ebay_user_token.json').success(function (data) {
      if (data.status) {
        stores.ebay.show_url = false;
      }
    }).error(notification.server_error);
  };

  //Import related functions
  var import_products = function (stores, report_id) {
    //return $http.get('/products/import_products/' + stores.single.id + '.json?reportid=' + report_id).success(function (data) {
      return $http.get('/products/import_products.json?reportid=' + report_id + '&id=' + stores.single.id).success(function (data) {
      if (data.status) {
        stores.import.product.status = "Successfully imported " + data.success_imported + " of " + data.total_imported +
          " products. " + data.previous_imported + " products were previously imported";
        if(stores.general_settings.email_address_for_packer_notes!=undefined && stores.general_settings.email_address_for_packer_notes!=0) {
          notification.notify("Your request has been queued. you will receive an email when products import is complete", 1);
        } else {
          notification.notify("Your request has been queued.", 1);
        }
      } else {
        stores.import.product.status = "";
        for (var j = 0; j < data.messages.length; j++) {
          stores.import.product.status += data.messages[j] + " ";
        }
      }
    }).error(function (data) {
      stores.import.product.status = "Import failed. Please check your credentials";
    });
  };

  var import_orders = function (stores) {
    return $http.get('/orders/import_orders/' + stores.single.id + '.json').success(function (data) {
      if (data.status) {
        stores.import.order.status = "Successfully imported " + data.success_imported + " of " + data.total_imported +
          " orders. " + data.previous_imported + " orders were previously imported";
      } else {
        stores.import.order.status = "";
        for (var j = 0; j < data.messages.length; j++) {
          stores.import.order.status += data.messages[j] + " ";
        }
      }
    }).error(function (data) {
      stores.import.order.status = "Import failed. Please check your credentials.";
    });
  };

  var import_images = function (stores, report_id) {
    return $http.get('/products/import_images/' + stores.single.id + '.json').success(function (data) {
      if (data.status) {
        stores.import.image.status = "Successfully imported " + data.success_imported + " of " + data.total_imported +
          " images. " + data.previous_imported + " images were previously imported";
      } else {
        stores.import.image.status = "";
        for (var j = 0; j < data.messages.length; j++) {
          stores.import.image.status += data.messages[j] + " ";
        }
      }
    }).error(function (data) {
      stores.import.image.status = "Import failed. Please check your credentials.";
    });
  };

  var import_amazon_request = function (stores) {
    return $http.get('/products/requestamazonreport/' + stores.single.id + '.json').success(function (data) {
      if (data.status) {
        stores.import.product.status = "Report for product import has been submitted. " +
          "Please check status in few minutes to import the products";
        stores.single.productgenerated_report_id = '';
        stores.single.productreport_id = data.requestedreport_id;
      } else {
        stores.import.product.status = "Report request failed. Please check your credentials."
      }
    }).error(function (data) {
      stores.import.product.status = "Report request failed. Please check your credentials.";
    });
  };

  var import_amazon_check = function (stores) {
    return $http.get('/products/checkamazonreportstatus/' + stores.single.id + '.json').success(function (data) {
      if (data.status) {
        stores.import.product.status = data.report_status;
        stores.single.productgenerated_report_id = data.generated_report_id;
      } else {
        stores.import.product.status = "Error checking status."
      }
    }).error(function (data) {
      stores.import.product.status = "Error checking status. Please try again later";
    });
  };

  //csv related functions
  var csv_import_data = function (stores, id) {
    return $http.post('/stores/'+id+'/csv_import_data.json?&type=' + stores.single.type).
      error(notification.server_error);
  };

  var csv_do_import = function (csv) {
    return $http.post('/stores/'+csv.current.store_id+'/csv_do_import.json', csv.current).success(function (data) {
      if (data.status) {
        notification.notify("CSV import queued successfully.", 1);
        csv.current = {};
        csv.importer = {};
      } else {
        notification.notify(data.messages, 0);
        csv.current.rows = csv.current.rows + data.last_row;
      }
    }).error(notification.server_error);
  };

  var csv_product_import_cancel = function (id) {
    return $http.post('/stores/'+id+'/csv_product_import_cancel.json').success(function (data) {
      notification.notify(data['error_messages']);
      notification.notify(data['success_messages'], 1);
      notification.notify(data['notice_messages'], 2);
    }).error(notification.server_error);
  };
  var update_csv_map = function (stores, map) {
    return $http.post('/stores/'+stores.single.id+'/update_csv_map.json', {
      map: map
    }).success(function (data) {
      if (data.status) {
        if (map.kind == 'order') {
          stores.csv.mapping.order_csv_map_id = map.id;
        } else if (map.kind == 'product') {
          stores.csv.mapping.product_csv_map_id = map.id;
        } else {
          stores.csv.mapping.kit_csv_map_id = map.id;
        };

      } else {
        notification.notify(data['messages']);
      };
    }).error(notification.server_error);
  };

  var delete_csv_map = function (stores, kind) {
    return $http.post('/stores/'+stores.single.id+'/delete_csv_map.json', {
      kind: kind
    }).success(function (data) {
      if (data.status) {
        if (kind == 'order') {
          stores.csv.mapping.order_csv_map_id = null;
        } else if (kind == 'product') {
          stores.csv.mapping.product_csv_map_id = null;
        } else {
          stores.csv.mapping.kit_csv_map_id = null;
        };

      } else {
        notification.notify(data['messages']);
      };
    }).error(notification.server_error);
  };
  var get_csv_maps = function (stores) {
    return $http.get('/stores/csv_map_data.json').success(function (data) {
      stores.csv.maps = data;
    }).error(notification.server_error);
  };

  var update_products = function (store_id) {
    return $http.put('/stores/' + store_id + '/update_products.json', null).success(
      function (data) {
        if (data.status) {
          notification.notify("CSV imported successfully", 1);
          csv.current = {};
          csv.importer = {};
        } else {
          notification.notify(data.messages, 0);
          csv.current.rows = csv.current.rows + data.last_row;
        }
      }).error(notification.server_error);
  };

  var verify_tags = function (store_id) {
    return $http.get('/stores/' + store_id + '/verify_tags.json').success(
      function (data) {
      }).error(notification.server_error);
  }

  var update_all_locations = function (store_id) {
    return $http.put('/stores/' + store_id + '/update_all_locations.json', null).success(
      function (data) {
      }).error(notification.server_error);
  }

  var fix_import_dates = function (store_id) {
    return $http.put('/shipstation_rest_credentials/' + store_id + '/fix_import_dates.json', null).success(function(data) {
      if (data.status) {
        notification.notify(data.messages, 1);
      } else {
        notification.notify(data.messages, 0);
      }
    }).error(notification.server_error);
  };

  var shopfiy_disconnect = function (store_id) {
    return $http.put('/shopify/' + store_id + '/disconnect.json', null).error(
      notification.server_error
    );
  }

  var big_commerce_disconnect = function (store_id) {
    return $http.put('/big_commerce/' + store_id + '/disconnect.json', null).error(
      notification.server_error
    );
  }

  var disconnect_magento = function (store_id) {
    return $http.put('/magento_rest/' + store_id + '/disconnect.json', null).error(
      notification.server_error
    );
  }

  var pull_store_inventory = function (store_id) {
    return $http.get('/stores/' + store_id + '/pull_store_inventory.json', null).success(
      function (data) {
      }).error(notification.server_error);
  }

  var push_store_inventory = function (store_id) {
    return $http.get('/stores/' + store_id + '/push_store_inventory.json', null).success(
      function (data) {
      }).error(notification.server_error);
  }

  var get_magento_aurthorize_url = function (store_id) {
    return $http.get('/magento_rest/' + store_id + '/magento_authorize_url.json', null).success(
      function (data) {
      }).error(notification.server_error);
  }

  var get_magento_access_token = function (store) {
    return $http.get('/magento_rest/' + store.id + '/get_access_token.json?oauth_varifier='+store.oauth_varifier , null).success(
      function (data) {
      }).error(notification.server_error);
  }

  var check_connection = function (store_type, store_id) {
    var url = "";
    if (store_type=="BigCommerce") {
      url = '/big_commerce/' + store_id + '/check_connection.json';
    } else if (store_type=="Magento API 2"){
      url = '/magento_rest/' + store_id + '/check_connection.json';
    }
    return $http.get(url, null).success(
      function (data) {
        return data;
      }
    ).error(notification.server_error);
  }

  //Public facing API
  return {
    model: {
      get: get_default
    },
    setup: {
      update: update_setup
    },
    list: {
      get: get_list,
      update: update_list,
      update_node: update_list_node,
      select_notification: select_notification
    },
    single: {
      get: get_single,
      get_system: get_system,
      can_create: can_create_single,
      validate_create: validate_create_single,
      update: create_update_single,
      update_ftp: create_update_ftp_credentials,
      connect: connect_ftp_server,
      pull_inventory: pull_store_inventory,
      push_inventory: push_store_inventory,
      amazon_products_import: amazon_products_import
    },
    ebay: {
      sign_in_url: {
        get: ebay_sign_in_url
      },
      user_token: {
        fetch: ebay_token_fetch,
        delete: ebay_token_delete,
        update: ebay_token_update
      }
    },
    import: {
      products: import_products,
      orders: import_orders,
      images: import_images,
      amazon: {
        request: import_amazon_request,
        check: import_amazon_check
      }
    },
    csv: {
      import: csv_import_data,
      do_import: csv_do_import,
      cancel_product_import: csv_product_import_cancel,
      map: {
        get: get_csv_maps,
        update: update_csv_map,
        delete: delete_csv_map
      }
    },
    update: {
      products: update_products
    },
    shipstation: {
      verify_tags: verify_tags,
      update_all_locations: update_all_locations,
      fix_dates: fix_import_dates
    },
    shopify: {
      disconnect: shopfiy_disconnect
    },
    big_commerce: {
      check_connection: check_connection,
      disconnect: big_commerce_disconnect
    },
    magento: {
      get_aurthorize_url: get_magento_aurthorize_url,
      get_access_token: get_magento_access_token,
      disconnect: disconnect_magento,
      check_connection: check_connection,
    }
  };
}]);
