groovepacks_controllers.controller('storeSingleModal', ['$scope', 'store_data', '$window', '$sce', '$interval', '$state', '$stateParams', '$modal',
  '$modalInstance', '$timeout', 'hotkeys', 'stores', 'warehouses', 'notification', '$q', 'groov_translator',
  function (scope, store_data, $window, $sce, $interval, $state, $stateParams, $modal, $modalInstance, $timeout, hotkeys, stores, warehouses, notification, $q, groov_translator) {
    var myscope = {};

    /**
     * Public methods
     */

    scope.ok = function () {
      $modalInstance.close("ok-button-click");
    };
    scope.cancel = function () {
      $modalInstance.dismiss("cancel-button-click");
    };

    scope.update = function (reason) {
      if (reason == "cancel-button-click") {
        myscope.rollback();
      } else if (reason == "csv-modal-closed") {
        scope.update_single_store(true);
      } else if (typeof scope.stores.single.id != "undefined") {
        // scope.update_single_store(false);
        scope.update_single_store(true);
      }
    };

    scope.disconnect_ebay_seller = function () {
      stores.ebay.user_token.delete(scope.stores).then(function () {
        myscope.store_single_details(scope.stores.single.id, true);
      });
    };

    scope.disconnect_shopify = function () {
      stores.shopify.disconnect(scope.stores.single.id).then(function () {
        myscope.store_single_details(scope.stores.single.id, true);
      });
    }

    scope.import_orders = function (report_id) {
      scope.stores.import.order.status = "Import in progress";
      scope.stores.import.order.status_show = true;
      scope.update_single_store(false).then(function () {
        stores.import.orders(scope.stores);
      });

    };

    scope.copy_acknowledgement = function () {
      scope.copy_text.text = 'Copied to clipboard';
      scope.copy_text.class = 'label label-success';
      $timeout(function () {
        scope.copy_text.text = 'Click Here to copy to clipboard';
        scope.copy_text.class = '';
      }, 2000);
    };

    scope.import_images = function (report_id) {
      scope.stores.import.image.status = "Import in progress";
      scope.stores.import.image.status_show = true;
      scope.update_single_store(false).then(function () {
        stores.import.images(scope.stores, report_id);
      });

    };

    scope.update_products = function () {
      scope.stores.update.products.status = "Update in progress";
      scope.stores.update.products.status_show = true;
      stores.update.products($stateParams.storeid).then(function () {
        scope.stores.update.products.status = "Update completed";
      });
    };

    scope.import_products = function (report_id) {
      scope.stores.import.product.status = "Import in progress";
      scope.stores.import.product.status_show = true;
      scope.update_single_store(false).then(function () {
        stores.import.products(scope.stores, scope.stores.single.productgenerated_report_id);
      });
    };

    scope.request_import_products = function () {
      scope.stores.import.product.status = "Import request in progress";
      scope.stores.import.product.status_show = true;
      stores.import.amazon.request(scope.stores);
    };

    scope.check_request_import_products = function () {
      scope.stores.import.product.status = "Checking status of the request";
      scope.stores.import.product.status_show = true;
      stores.import.amazon.check(scope.stores);
    };

    scope.copydata = function (event) {
      if (event) {
        if (scope.stores.single.store_type == 'Magento') {
          scope.stores.single.producthost = scope.stores.single.host;
          scope.stores.single.productusername = scope.stores.single.username;
          scope.stores.single.productpassword = scope.stores.single.password;
          scope.stores.single.productapi_key = scope.stores.single.api_key;
        } else if (scope.stores.single.store_type == 'Ebay') {
          scope.stores.single.productebay_auth_token = scope.stores.single.ebay_auth_token;
        } else if (scope.stores.single.store_type == 'Amazon') {
          scope.stores.single.productmarketplace_id = scope.stores.single.marketplace_id;
          scope.stores.single.productmerchant_id = scope.stores.single.merchant_id;
        } else if (scope.stores.single.store_type == 'Shipstation') {
          scope.stores.single.productusername = scope.stores.single.username;
          scope.stores.single.productpassword = scope.stores.single.password;
        }
      } else {
        if (scope.stores.single.store_type == 'Magento') {
          scope.stores.single.producthost = "";
          scope.stores.single.productusername = "";
          scope.stores.single.productpassword = "";
          scope.stores.single.productapi_key = "";
        } else if (scope.stores.single.store_type == 'Ebay') {
          scope.stores.single.productebay_auth_token = "";
        } else if (scope.stores.single.store_type == 'Amazon') {
          scope.stores.single.productmarketplace_id = "";
          scope.stores.single.productmerchant_id = "";
        } else if (scope.stores.single.store_type == 'Shipstation') {
          scope.stores.single.productusername = "";
          scope.stores.single.productpassword = "";
        }
      }
    };

    scope.change_opt = function (id, value) {
      scope.stores.single[id] = value;
      scope.update_single_store(true);
    };

    myscope.store_single_details = function (id, new_rollback) {
      for (var i = 0; i < scope.stores.list.length; i++) {
        if (scope.stores.list[i].id == id) {
          scope.stores.current = parseInt(i);
          break;
        }
      }
      return stores.single.get(id, scope.stores).then(function (response) {
        if (response.data.status) {
          scope.edit_status = true;
          if (typeof new_rollback == 'boolean' && new_rollback) {
            myscope.single = {};
            angular.copy(scope.stores.single, myscope.single);
          }
        }
      });
    };

    scope.update_ftp_credentials = function () {
      if (typeof scope.stores.single.connection_established != 'undefined') {
        stores.single.update_ftp(scope.stores).then(function(data) {
          myscope.init();
        });
      };
    };

    scope.establish_connection = function() {
      if (typeof scope.stores.single.host == 'undefined' ||
        typeof scope.stores.single.username == 'undefined' ||
        typeof scope.stores.single.password == 'undefined' ||
        typeof scope.stores.single.connection_method == 'undefined') {
        notification.notify("Please fillout all the credentials for the ftp store");
      } else{
        stores.single.update_ftp(scope.stores).then(function(data) {
          stores.single.connect(scope.stores).then(function(data) {
            myscope.init();
          });
        });
      };
    };

    scope.update_single_store = function (auto) {
      if (scope.edit_status || stores.single.validate_create(scope.stores)) {
        return stores.single.update(scope.stores, auto).success(function (data) {
          if (data.status && data.store_id) {
            if (scope.stores.single['id'] != 0) {
              myscope.store_single_details(data.store_id);
            }
            if (typeof scope.stores.single['id'] == "undefined") {
              myscope.store_single_details(data.store_id);
            }
            if (!auto) {
              //Use FileReader API here if it exists (post prototype feature)
              if (data.csv_import && data.store_id) {
                if (scope.stores.csv.mapping[scope.stores.single.type + '_csv_map_id'] && !scope.start_editing_map) {
                  var result = $q.defer();
                  for (var i = 0; i < scope.stores.csv.maps[scope.stores.single.type].length; i++) {
                    if (scope.stores.csv.mapping[scope.stores.single.type + '_csv_map_id'] == scope.stores.csv.maps[scope.stores.single.type][i].id) {
                      var current_map = jQuery.extend(true, {}, scope.stores.csv.maps[scope.stores.single.type][i]);
                      break;
                    }
                  }


                  current_map.map.store_id = scope.stores.single.id;
                  current_map.map.type = scope.stores.single.type;
                  current_map.map.name = current_map.name;
                  current_map.map.flag = 'file_upload';
                  if (current_map.map.type == 'order') {
                    if (current_map.map.order_date_time_format == null || current_map.map.order_date_time_format == 'Default') {
                      if(confirm("Order Date/Time foramt has not been set. Would you like to continue using the current Date/Time for each imported order? Click ok to continue the import using the current date/time for all orders or click cancel and edit map to select one.")){
                        current_map.map.order_placed_at = new Date();
                        stores.csv.do_import({current: current_map.map});
                        myscope.reset_choose_file();
                        $modalInstance.close("csv-modal-closed");
                        result.resolve();
                      } else {
                        result.resolve();
                      };
                    } else {
                      var not_found = true
                      for (var i = 0; i < Object.keys(current_map.map.map).length; i++) {
                        if (current_map.map.map[i].name == "Order Date/Time") {
                          not_found &= false
                          break;
                        } else {
                          continue;
                        }
                        ;
                      }
                      if (not_found) {
                        if (confirm("An Order Date/Time has not been mapped. Would you like to continue using the current Date/Time for each imported order?")) {
                          current_map.map.order_placed_at = new Date();
                          stores.csv.do_import({current: current_map.map});
                          myscope.reset_choose_file();
                          $modalInstance.close("csv-modal-closed");
                          result.resolve();
                        };
                      } else {
                        current_map.map.order_placed_at = null;
                        stores.csv.do_import({current: current_map.map});
                        myscope.reset_choose_file();
                        $modalInstance.close("csv-modal-closed");
                        result.resolve();
                      };
                    };

                  } else {
                    stores.csv.do_import({current: current_map.map});
                    myscope.reset_choose_file();
                    $modalInstance.close("csv-modal-closed");
                    result.resolve();
                  };
                  // stores.csv.do_import({current:current_map.map});
                  // $modalInstance.close("csv-modal-closed");
                  return result.promise;
                } else {
                  var csv_modal;
                  if (scope.stores.single.type == 'order' || scope.stores.single.type == 'kit') {
                    csv_modal = $modal.open({
                      templateUrl: '/assets/views/modals/settings/stores/csv_import.html',
                      controller: 'csvSingleModal',
                      size: 'lg',
                      resolve: {
                        store_data: function () {
                          return scope.stores;
                        }
                      }
                    });
                  } else if (scope.stores.single.type == 'product') {
                    csv_modal = $modal.open({
                      templateUrl: '/assets/views/modals/settings/stores/csv_import_detailed.html',
                      controller: 'csvDetailedModal',
                      size: 'lg',
                      resolve: {
                        store_data: function () {
                          return scope.stores;
                        }
                      }
                    });
                  };
                  csv_modal.result.finally(function () {
                    myscope.reset_choose_file();
                    $modalInstance.close("csv-modal-closed");
                  });
                };
              } else {
                notification.notify("Please choose a file to import first",0);
              };
            }
          }

          scope.start_editing_map = false;
        });
      }
    };

    myscope.reset_choose_file = function() {
      delete scope.stores.single['orderfile'];
      delete scope.stores.single['productfile'];
      delete scope.stores.single['kitfile'];
    };

    scope.import_map = function () {
      scope.update_single_store(false);
    };

    scope.import_ftp = function() {
      scope.stores.single.type = 'order';
      if (scope.stores.csv.mapping[scope.stores.single.type + '_csv_map_id'] && !scope.start_editing_map) {
        var result = $q.defer();
        for (var i = 0; i < scope.stores.csv.maps[scope.stores.single.type].length; i++) {
          if (scope.stores.csv.mapping[scope.stores.single.type + '_csv_map_id'] == scope.stores.csv.maps[scope.stores.single.type][i].id) {
            var current_map = jQuery.extend(true, {}, scope.stores.csv.maps[scope.stores.single.type][i]);
            break;
          }
        }
        current_map.map.store_id = scope.stores.single.id;
        current_map.map.type = scope.stores.single.type;
        current_map.map.name = current_map.name;
        current_map.map.flag = 'ftp_download';

        if (current_map.map.order_date_time_format == null || current_map.map.order_date_time_format == 'Default') {
          current_map.map.order_placed_at = new Date();
          stores.csv.do_import({current: current_map.map});
          $modalInstance.close("csv-modal-closed");
          result.resolve();
        } else {
          var not_found = true
          for (var i = 0; i < Object.keys(current_map.map.map).length; i++) {
            if (current_map.map.map[i].name == "Order Date/Time") {
              not_found &= false
              break;
            } else {
              continue;
            };
          }
          if (not_found) {
            current_map.map.order_placed_at = new Date();
            stores.csv.do_import({current: current_map.map});
            $modalInstance.close("csv-modal-closed");
            result.resolve();
          } else {
            current_map.map.order_placed_at = null;
            stores.csv.do_import({current: current_map.map});
            $modalInstance.close("csv-modal-closed");
            result.resolve();
          };
        };
        return result.promise;
      }
    }

    scope.edit_map = function () {
      scope.start_editing_map = true;
      scope.update_single_store(false);
    };

    scope.select_map = function (map) {
      stores.csv.map.update(scope.stores, map);
    };

    scope.clear_map = function (kind) {
      stores.csv.map.delete(scope.stores, kind);
    };

    scope.shipstation_verify_tags = function (store_id) {
      stores.shipstation.verify_tags(store_id).then(function (response) {
        scope.verification_tags = response.data.data;
      });
    };

    scope.shipstation_update_all_locations = function (store_id) {
      scope.shipstation_loc_update_response = {}
      stores.shipstation.update_all_locations(store_id).then(function (response) {
        scope.shipstation_loc_update_response = response.data;
      });
    };

    myscope.open_popup = function (url) {
      var w = 1000;
      var h = 400;
      var left_adjust = angular.isDefined($window.screenLeft) ? $window.screenLeft : $window.screen.left;
      var top_adjust = angular.isDefined($window.screenTop) ? $window.screenTop : $window.screen.top;
      var width = $window.innerWidth ? $window.innerWidth : $window.document.documentElement.clientWidth ? $window.document.documentElement.clientWidth : $window.screen.width;
      var height = $window.innerHeight ? $window.innerHeight : $window.document.documentElement.clientHeight ? $window.document.documentElement.clientHeight : $window.screen.height;

      var left = ((width / 2) - (w / 2)) + left_adjust;
      var top = ((height / 2) - (h / 2)) + top_adjust;

      var popup = $window.open(url, '', "top=" + top + ", left=" + left + ", width=" + w + ", height=" + h);
      var interval = 1000;

      var i = $interval(function () {
        try {
          //console.log("Tick-popup");
          // value is the user_id returned from paypal
          if (popup == null || popup.closed) {
            $interval.cancel(i);
            //TODO: move this out to a callback
            myscope.store_single_details(scope.stores.single.id, true);
          }
        } catch (e) {
          console.error(e);
        }
      }, interval);
    };
    scope.launch_ebay_popup = function () {
      //TODO: Move this into a service/directive after some testing is done
      var ebay_url = $sce.trustAsResourceUrl(scope.stores.ebay.signin_url + '&ruparams=redirect%3Dtrue%26editstatus%3D' + scope.edit_status + '%26name%3D' +
        scope.stores.single.name + '%26status%3D' + scope.stores.single.status + '%26storetype%3D' +
        scope.stores.single.store_type + '%26storeid%3D' + scope.stores.single.id + '%26inventorywarehouseid%3D' + scope.stores.single.inventory_warehouse_id + '%26importimages%3D' + scope.stores.single.import_images +
        '%26importproducts%3D' + scope.stores.single.import_products + '%26messagetocustomer%3D' + scope.stores.single.thank_you_message_to_customer + '%26tenantname%3D' + scope.stores.ebay.current_tenant);

      myscope.open_popup(ebay_url);
    };

    scope.launch_shopify_popup = function () {
      $timeout(function () {
        var shopify_url = $sce.trustAsResourceUrl(scope.stores.single.shopify_permission_url);
        if (shopify_url == null) {
          if (typeof scope.stores.single.shop_name == 'undefined') {
            notification.notify("Please enter your store name first.");
          }
        } else {
          myscope.open_popup(shopify_url);
        }
      }, 200);
    };

    myscope.rollback = function () {
      if (typeof myscope.single == "undefined" || typeof myscope.single.id == "undefined") {
        if (typeof scope.stores.single['id'] != "undefined") {
          stores.list.update('delete', {setup: {status: ''}, list: [{id: scope.stores.single.id, checked: true}]});
        }
      } else {
        scope.stores.single = {};
        angular.copy(myscope.single, scope.stores.single);
        scope.update_single_store(true);
      }
    };

    myscope.up_key = function (event) {
      event.preventDefault();
      event.stopPropagation();
      if ($state.includes('settings.stores.single')) {
        if (scope.stores.current > 0) {
          myscope.load_item(scope.stores.current - 1);
        } else {
          alert("Already at the top of the list");
        }
      }
    };

    myscope.down_key = function (event) {
      event.preventDefault();
      event.stopPropagation();
      if ($state.includes('settings.stores.single')) {
        if (scope.stores.current < scope.stores.list.length - 1) {
          myscope.load_item(scope.stores.current + 1);
        } else {
          alert("Already at the bottom of the list");
        }
      }
    };

    myscope.load_item = function (id) {
      var newStateParams = angular.copy($stateParams);
      newStateParams.storeid = "" + scope.stores.list[id].id;
      myscope.store_single_details(scope.stores.list[id].id, true);
      $state.go($state.current.name, newStateParams);
    };

    scope.export_active_products = function () {
      $window.open('/stores/export_active_products.csv');
    };

    myscope.init = function () {
      scope.translations = {
        "tooltips": {
          "ftp_address": "",
          "import_from_ftp": ""
        }
      };
      groov_translator.translate('settings.csv_modal', scope.translations);
      scope.stores = store_data;
      scope.stores.single = {};
      scope.stores.ebay = {};
      scope.stores.csv = {};
      scope.stores.csv.maps = {order: [], product: []};
      scope.stores.csv.mapping = {};
      scope.start_editing_map = false;
      scope.stores.single.file_path = '';
      scope.stores.import = {
        order: {},
        product: {},
        image: {}
      };

      scope.copy_text = {
        text: 'Click Here to copy to clipboard',
        class: ''
      };

      scope.stores.types = {};
      scope.warehouses = warehouses.model.get();
      warehouses.list.get(scope.warehouses).then(function () {
        if (typeof scope.stores.single['inventory_warehouse_id'] != "number") {
          for (var i = 0; i < scope.warehouses.list.length; i++) {
            if (scope.warehouses.list[i].info.is_default) {
              scope.stores.single.inventory_warehouse_id = scope.warehouses.list[i].info.id;
              //console.log(scope.stores);
              break;
            }
          }
        }
      });

      stores.csv.map.get(scope.stores);


      scope.stores.types = {
        Magento: {
          name: "Magento",
          file: "/assets/views/modals/settings/stores/magento.html"
        },
        Ebay: {
          name: "Ebay",
          file: "/assets/views/modals/settings/stores/ebay.html"
        },
        Amazon: {
          name: "Amazon",
          file: "/assets/views/modals/settings/stores/amazon.html"
        },
        CSV: {
          name: "CSV",
          file: "/assets/views/modals/settings/stores/csv.html"
        },
        "Shipstation API 2": {
          name: "Shipstation API 2",
          file: "/assets/views/modals/settings/stores/shipstation_rest.html"
        },
        Shipworks: {
          name: "Shipworks",
          file: "/assets/views/modals/settings/stores/shipworks.html"
        },
        Shopify: {
          name: "Shopify",
          file: "/assets/views/modals/settings/stores/shopify.html"
        }
      };


      //Determine create/ edit/ redirect call

      scope.stores.import.order.type = 'apiimport';
      scope.stores.import.product.type = 'apiimport';
      scope.stores.ebay.show_url = true;
      scope.stores.ebay.signin_url_status = true;
      if ($state.includes('settings.stores.create')) {
        scope.edit_status = false;
        scope.redirect = false;
        scope.stores.single.status = 1;
        scope.stores.ebay.show_url = true;
        stores.ebay.sign_in_url.get(scope.stores);
        scope.stores.single.import_images = true;
        scope.stores.single.import_products = true;
        scope.stores.single.shall_import_awaiting_shipment = true;
      } else {
        scope.edit_status = true;
        scope.redirect = ($stateParams.redirect || ($stateParams.action == "create"));
        if (scope.redirect) {
          if (typeof $stateParams['editstatus'] != 'undefined' && $stateParams.editstatus == 'true') {
            scope.edit_status = $stateParams.editstatus;
            stores.ebay.user_token.update(scope.stores, $stateParams.storeid);

            scope.stores.single.id = $stateParams.storeid;

            scope.stores.single.name = $stateParams.name;

            scope.stores.single.status = ($stateParams.status == 'true');
            scope.stores.single.store_type = $stateParams.storetype;

            scope.stores.single.inventory_warehouse_id = parseInt($stateParams.inventorywarehouseid);
            scope.stores.single.import_images = ($stateParams.importimages == 'true');
            scope.stores.single.import_products = ($stateParams.importproducts == 'true');
            scope.stores.single.thank_you_message_to_customer = $stateParams.messagetocustomer;
          } else {
            scope.stores.single.name = $stateParams.name;
            scope.stores.single.status = ($stateParams.status == true);
            scope.stores.single.store_type = $stateParams.storetype;

            scope.stores.single.inventory_warehouse_id = parseInt($stateParams.inventorywarehouseid);
            scope.stores.single.import_images = ($stateParams.importimages == 'true');
            scope.stores.single.import_products = ($stateParams.importproducts == 'true');
            scope.stores.single.thank_you_message_to_customer = $stateParams.messagetocustomer;
            stores.ebay.user_token.fetch(scope.stores).then(function (response) {
              if (response.data.status) {
                scope.update_single_store(true);
              }
            });
          }
          if (typeof scope.stores.single.status == "undefined") {
            scope.stores.single.status = 1;
          }
        } else {
          myscope.store_single_details($stateParams.storeid, true);
        }

      }


      scope.$on("fileSelected", function (event, args) {
        if (args.name == 'orderfile' || args.name == 'productfile' || args.name == 'kitfile') {
          scope.$apply(function () {
            scope.stores.single[args.name] = args.file;
          });
          // $("input[type='file']").val('');
          if (args.name == 'orderfile') {
            scope.stores.single.type = 'order';
          } else if (args.name == 'productfile') {
            scope.stores.single.type = 'product';
          } else if (args.name == 'kitfile') {
            scope.stores.single.type = 'kit';
          }
          //scope.update_single_store(false);
        }
      });
      $modalInstance.result.then(scope.update, scope.update);
      hotkeys.bindTo(scope).add({
        combo: 'up',
        description: 'Previous user',
        callback: myscope.up_key
      }).add({
        combo: 'down',
        description: 'Next user',
        callback: myscope.down_key
      })

    };

    myscope.init();

  }]);
