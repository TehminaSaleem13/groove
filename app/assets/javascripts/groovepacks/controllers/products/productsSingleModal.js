groovepacks_controllers.
  controller('productsSingleModal', ['$scope', 'auth', 'product_data', 'load_page', 'product_id', 'hotkeys', '$state', '$stateParams', '$modalInstance', '$timeout', '$modal', '$q', 'groov_translator', 'products', 'warehouses', 'generalsettings', 'scanPack',
    function (scope, auth, product_data, load_page, product_id, hotkeys, $state, $stateParams, $modalInstance, $timeout, $modal, $q, groov_translator, products, warehouses, generalsettings, scanPack) {
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
        hotkeys.del('up');
        hotkeys.del('down');
        if (reason == "cancel-button-click") {
          myscope.rollback();
        } else {
          if (!scope.alias_added) {
            scope.update_single_product(false);
          }
        }
      };

      myscope.product_single_details = function (id, new_rollback) {
        //console.log(index);
        //console.log(scope.products);

        for (var i = 0; i < scope.products.list.length; i++) {
          if (scope.products.list[i].id == id) {
            scope.products.current = parseInt(i);
            break;
          }
        }

        products.single.get(id, scope.products, new_rollback).success(function (data) {
          warehouses.list.get(scope.warehouses).success(function () {
            for (var i = 0; i < scope.products.single.inventory_warehouses.length; i++) {
              for (var j = 0; j < scope.warehouses.list.length; j++) {
                if (scope.products.single.inventory_warehouses[i].warehouse_info.id == scope.warehouses.list[j].info.id) {
                  scope.warehouses.list.splice(j, 1);
                  break;
                }
              }
            }
          });

          if (typeof new_rollback == 'boolean' && new_rollback) {
            myscope.single = {};
            angular.copy(scope.products.single, myscope.single);
          }
        });
      };

      myscope.rollback = function () {
        if ($state.params.new_product) {
          products.list.update('delete', {
            selected: [{id: scope.products.single.basicinfo.id, checked: true}],
            setup: {select_all: false, inverted: false, productArray: []}
          }).then(function () {
            if ($state.current.name == 'products.type.filter.page') {
              $state.reload();
            }
          });
        } else {
          scope.products.single = {};
          angular.copy(myscope.single, scope.products.single);
          scope.update_single_product(false);
        }
      };

      scope.load_kit = function (kit, event) {
        if (typeof event != 'undefined') {
          event.preventDefault();
          event.stopPropagation();
        }
        var kit_modal = $modal.open({
          templateUrl: '/assets/views/modals/product/main.html',
          controller: 'productsSingleModal',
          size: 'lg',
          resolve: {
            product_data: function () {
              return scope.kit_products
            },
            load_page: function () {
              return function () {
                var req = $q.defer();
                req.reject();
                return req.promise;
              };
            },
            product_id: function () {
              return kit.option_product_id;
            }
          }
        });
        kit_modal.result.finally(function () {
          myscope.product_single_details(scope.products.single.basicinfo.id);
          myscope.add_hotkeys();
        });
      };

      scope.product_alias = function (type, exceptions, id) {
        var alias_modal = $modal.open({
          templateUrl: '/assets/views/modals/product/alias.html',
          controller: 'aliasModal',
          size: 'lg',
          resolve: {
            type: function () {
              return type
            },
            exceptions: function () {
              return exceptions
            },
            id: function () {
              return id;
            }
          }
        });
        alias_modal.result.then(function (data) {
          myscope.add_alias_product(type, data);
          scope.alias_added = true;
        });
      };
      scope.add_image_for_receiving_instructions = function () {
        var receiving_image_modal = $modal.open({
          templateUrl: '/assets/views/modals/product/receiving_images.html',
          controller: 'productReceivingImageModal',
          size: 'md',
          resolve: {
            product_data: function () {
              return scope.products;
            },
            product_id: function () {
              return $stateParams.product_id;
            }
          }
        });
        receiving_image_modal.result.then(function (data) {
          myscope.product_single_details(scope.products.single.basicinfo.id);
        });
      };
      scope.add_image = function () {
        $("#product_image" + scope.custom_identifier).click();
      };
      scope.remove_image = function (index) {
        scope.products.single.images.splice(index, 1);
        scope.update_single_product();
      };
      scope.remove_instruction_image = function (image) {
        image.added_to_receiving_instructions = false;
        products.single.update_image(image).then(function () {
          myscope.product_single_details(scope.products.single.basicinfo.id);
        });
      };
      scope.$on("fileSelected", function (event, args) {
        $("input[type='file']").val('');
        if (args.name == 'product_image') {
          scope.$apply(function () {
            products.single.image_upload(scope.products, args).then(function (response) {
              myscope.product_single_details(scope.products.single.basicinfo.id);
            });
          });
        }
        ;
      });

      myscope.add_alias_product = function (type, args) {
        if (typeof args != "undefined") {
          if (type == 'kit') {
            products.single.kit.add(scope.products, args.selected).then(function (response) {
              //console.log(response.data);
              myscope.product_single_details(scope.products.single.basicinfo.id, true);
            });
          } else if (type == 'master_alias') {
            products.single.master_alias(scope.products, args.selected).then(function () {
              myscope.product_single_details(scope.products.single.basicinfo.id, true);
            });
          } else {
            products.single.alias(scope.products, args.selected).then(function () {
              myscope.product_single_details(args.selected[0], true);
            });
          }
        }
      };

      myscope.down_key = function (event) {
        event.preventDefault();
        event.stopPropagation();
        if (scope.products.current < scope.products.list.length - 1) {
          myscope.load_item(scope.products.current + 1);
        } else {
          load_page('next').then(function () {
            myscope.load_item(0);
          }, function () {
            alert("Already at the bottom of the list");
          });
        }
      };
      myscope.up_key = function (event) {
        event.preventDefault();
        event.stopPropagation();
        if (scope.products.current > 0) {
          myscope.load_item(scope.products.current - 1);
        } else {
          load_page('previous').then(function () {
            myscope.load_item(scope.products.list.length - 1);
          }, function () {
            alert("Already at the top of the list");
          });
        }
      };

      myscope.add_hotkeys = function () {
        hotkeys.del('up');
        hotkeys.del('down');
        hotkeys.del('esc');
        $timeout(function () {
          hotkeys.bindTo(scope).add({
            combo: 'up',
            description: 'Previous product',
            callback: myscope.up_key
          })
            .add({
              combo: 'down',
              description: 'Next product',
              callback: myscope.down_key
            }).add({
              combo: 'esc',
              description: 'Save and close modal',
              callback: function () {
              }
            });
        }, 2000);
      };

      scope.update_single_product = function (auto, post_fn) {
        //console.log(scope.products.single);
        scope.products.single.post_fn = post_fn;
        products.single.update(scope.products, auto).then(function () {
          myscope.product_single_details(scope.products.single.basicinfo.id);
        });
      };

      scope.update_product_sync_options = function (post_fn, auto) {
        //console.log(scope.products.single);
        products.single.update_sync_options(scope.products, auto).then(function () {
          myscope.product_single_details(scope.products.single.basicinfo.id);
        });
      };


      scope.add_warehouse = function (warehouse) {
        scope.products.single.inventory_warehouses.push({warehouse_info: warehouse.info, info: {}});
        scope.update_single_product();
      };

      scope.remove_warehouses = function () {
        var old_warehouses = scope.products.single.inventory_warehouses;
        scope.products.single.inventory_warehouses = [];
        for (var i = 0; i < old_warehouses.length; i++) {
          if (!old_warehouses[i].checked) {
            scope.products.single.inventory_warehouses.push(old_warehouses[i]);
          }
        }
        scope.update_single_product();
      };
      scope.change_opt = function (key, value) {
        scope.general_settings.single[key] = value;
        generalsettings.single.update(scope.general_settings);
      };

      scope.check_remove_prod_name = function () {
        if (scope.products.single.basicinfo.name == "New Product") {
          scope.products.single.basicinfo.name = '';
        }
      };

      scope.print_receive_label = function (event) {
        event.preventDefault();
        var prods = products.model.get();
        prods.selected.push({id: scope.products.single.basicinfo.id, checked: true});
        products.list.update('receiving_label', prods);
      };
      scope.remove_skus_from_kit = function () {
        var selected_skus = [];
        //console.log(scope.products.single.productkitskus);
        for (var i = 0; i < scope.products.single.productkitskus.length; i++) {
          if (scope.products.single.productkitskus[i].checked) {
            selected_skus.push(scope.products.single.productkitskus[i].option_product_id);
          }
        }
        products.single.kit.remove(scope.products, selected_skus).then(function (data) {
          myscope.product_single_details(scope.products.single.basicinfo.id);
        });
      };

      scope.acknowledge_activity = function (activity_id) {
        products.single.activity.acknowledge(activity_id).then(function (response) {
          myscope.product_single_details(scope.products.single.basicinfo.id);
        })
      };

      scope.change_setting = function (key, value) {
        scope.products.single.basicinfo[key] = value;
        scope.update_single_product();
      };


      myscope.load_item = function (id) {
        myscope.product_single_details(scope.products.list[id].id, true);
        if (myscope.update_state) {
          var newStateParams = angular.copy($stateParams);
          newStateParams.product_id = "" + scope.products.list[id].id;
          $state.go($state.current.name, newStateParams);
        }
      };

      myscope.init = function () {
        scope.translations = {
          "tooltips": {
            "sku": "",
            "barcode": "",
            "confirmation": "",
            "placement": "",
            "time_adjust": "",
            "skippable": "",
            "record_serial": "",
            "master_alias": "",
            "product_receiving_instructions": "",
            "intangible_item": "",
            "add_to_any_order": "",
            "type_in_scan_setting": "",
            "click_scanning_setting": ""
          }
        };
        groov_translator.translate('products.modal', scope.translations);


        scope.confirmation_setting_text = "Ask someone with \"Edit General Preferences\" permission to change the setting in <b>General Settings</b> page if you need to override it per product";
        if (auth.can('edit_general_prefs')) {
          scope.general_settings = generalsettings.model.get();
          generalsettings.single.get(scope.general_settings);
          scope.confirmation_setting_text = "<p><strong>You can change the global setting here</strong></p>" +
            "<div class=\"controls col-sm-offset-4 col-sm-3 \" ng-class=\"{'col-sm-offset-3':general_settings.single.conf_code_product_instruction=='optional' }\" dropdown>" +
            "<button class=\"dropdown-toggle groove-button label label-default\" ng-class=\"{'label-success':general_settings.single.conf_code_product_instruction=='always'," +
            " 'label-warning':general_settings.single.conf_code_product_instruction=='optional'}\">" +
            "<span ng-show=\"general_settings.single.conf_code_product_instruction=='always'\" translate>common.always</span>" +
            "<span ng-show=\"general_settings.single.conf_code_product_instruction=='optional'\" translate>common.optional</span>" +
            "<span ng-show=\"general_settings.single.conf_code_product_instruction=='never'\" translate>common.never</span>" +
            "<span class=\"caret\"></span>" +
            "</button>" +
            "<ul class=\"dropdown-menu\" role=\"menu\">" +
            "<li><a class=\"dropdown-toggle\" ng-click=\"change_opt('conf_code_product_instruction','always')\" translate>common.always</a></li>" +
            "<li><a class=\"dropdown-toggle\" ng-click=\"change_opt('conf_code_product_instruction','optional')\" translate>common.optional</a></li>" +
            "<li><a class=\"dropdown-toggle\" ng-click=\"change_opt('conf_code_product_instruction','never')\" translate>common.never</a></li>" +
            "</ul>" +
            "</div><div class=\"well-main\">&nbsp;</div>";
        }
        scope.scan_pack_settings = scanPack.settings.model();
        scanPack.settings.get(scope.scan_pack_settings);

        scope.custom_identifier = Math.floor(Math.random() * 1000);
        scope.products = product_data;
        scope.products.single.post_fn = null;

        /**
         * Public properties
         */
        scope.warehouses = warehouses.model.get();
        warehouses.list.get(scope.warehouses);
        scope.kit_products = products.model.get();
        scope.$watch('products.single.productkitskus', function () {
          if (typeof scope.products.single.basicinfo != "undefined" && scope.products.single.basicinfo.is_kit == 1) {
            scope.kit_products.list = [];
            for (var i = 0; i < scope.products.single.productkitskus.length; i++) {
              scope.kit_products.list.push({id: scope.products.single.productkitskus[i].option_product_id});
            }
          }
        });


        /**
         * private properties
         */
        scope._product_obj = null;
        scope.arraySkuEditableOptions = {
          array: true,
          update: function() { scope.update_single_product(true, "sku") },
          class: '',
          sortableOptions: {
            update: function() { scope.update_single_product(true, "sku") },
            axis: 'x'
          }
        };
        scope.arrayCatEditableOptions = {
          array: true,
          update: function() { scope.update_single_product(true, "category") },
          class: '',
          sortableOptions: {
            update: function() { scope.update_single_product(true, "category") },
            axis: 'x'
          }
        };
        scope.arrayEditableOptions = {
          array: true,
          update: function() { scope.update_single_product(true, "barcode") },
          class: '',
          sortableOptions: {
            update: function() { scope.update_single_product(true, "barcode") },
            axis: 'x'
          }
        };

        scope.warehouseGridOptions = {
          identifier: 'warehousesgrid',
          selectable: true,
          scrollbar: true,
          setup: {
            enable_inv_alert: function () {
              return scope.general_settings.single.low_inventory_alert_email;
            }
          },
          editable: {
            update: scope.update_single_product,
            elements: {
              available_inv: {type: 'number', min: 0},
              product_inv_alert_level: {type: 'number', min: 0},
              quantity_on_hand: {type: 'number', min: 0}
            }
          },
          all_fields: {
            name: {
              name: 'Warehouse Name',
              model: 'row.warehouse_info',
              editable: false,
              transclude: '<span>{{row.warehouse_info.name}}</span>'
            },
            status: {
              name: "Status",
              editable: false,
              transclude: '<span class="label label-default" ng-class="{\'label-success\': row.warehouse_info.status==\'active\'}">' +
              '{{row.warehouse_info.status}}' +
              '</span>'
            },
            available_inv: {
              name: 'Available Inv',
              model: 'row.info',
              editable: false,
              transclude: '<span>{{row.info.available_inv}}</span>'
            },

            allocated_inv: {
              name: 'Allocated Inv',
              model: 'row.info',
              editable: false,
              transclude: '<span>{{row.info.allocated_inv}}</span>'
            },
            quantity_on_hand: {
              name: 'QoH',
              model: 'row.info',
              col_length: 5,
              transclude: '<span>{{row.info.quantity_on_hand}}</span>'
            },
            sold_inv: {
              name: 'Sold Inv',
              model: 'row.info',
              editable: false,
              transclude: '<span>{{row.info.sold_inv}}</span>'
            },
            location_primary: {
              name: 'Primary Location',
              col_length: 14,
              model: 'row.info',
              transclude: '<span>{{row.info.location_primary}}</span>'
            },
            location_secondary: {
              name: 'Secondary Location',
              col_length: 14,
              model: 'row.info',
              transclude: '<span>{{row.info.location_secondary}}</span>'
            },
            location_tertiary: {
              name: 'Tertiary Location',
              col_length: 14,
              model: 'row.info',
              transclude: '<span>{{row.info.location_tertiary}}</span>'
            },
            product_inv_alert: {
              name: "Override Global Inv Alert Lvl",
              model: 'row.info',
              editable: false,
              transclude: '<div> <span groov-popover=\'If you would like to enable the Low Inventory Alerts you can do so in the <a ui-sref="settings.system.general" target="_blank">General Settings</a>\' ng-hide="{{options.setup.enable_inv_alert()}}">Off</span><div ng-show="{{options.setup.enable_inv_alert()}}" toggle-switch ng-model="row.info.product_inv_alert" groov-click="options.editable.update()"></div></div>'
            },
            product_inv_alert_level: {
              name: "Inv Alert Level",
              model: 'row.info',
              editable: false,
              transclude: '<div><span groov-popover=\'This product is currently using the global alert threshold.<br /> If you would like to enable the Low Inventory Alerts you can do so in the <a ui-sref="settings.system.general" target="_blank">General Settings</a>\' ng-hide="{{options.setup.enable_inv_alert()}}">{{row.info.product_inv_alert_level}}</span><div ng-show="{{options.setup.enable_inv_alert()}}"><div ng-show="{{row.info.product_inv_alert}}"><div groov-editable="options.editable" prop="{{field}}" ng-model="row.info" identifier="warehousesgrid_list-product_inv_alert_level-{{$index}}">{{row.info.product_inv_alert_level}}</div></div><div ng-hide="{{row.info.product_inv_alert}}" groov-popover=\'This product is currently using the alert threshold set in the <a ui-sref="settings.system.general" target="_blank">General Settings</a>. <br/>If you would like to set an alternate alert level for this product, please turn on the override switch.\'>{{row.info.product_inv_alert_level}}</div></div></div>'
            }
          }
        };

        scope.kitEditableOptions = {
          scrollbar: true,
          no_of_lines: 1,
          selectable: true,
          editable:{
            update: scope.update_single_product,
            elements: {
              qty: {type: 'number', min: 0},
              packing_order: {type: 'number', min: 0}
            },
            functions: {
              name: scope.load_kit
            }
          },
          all_fields: {
            name: {
              name: "Item Name",
              col_length: 25,
              editable: false,
              transclude: '<a href="" ng-click="options.editable.functions.name(row, event)" tooltip="{{row.name}}">{{row.name | cut:false:25}}</a>'
            },
            sku: {
              name: "Item SKU",
              col_length: 15,
              editable: false
            },
            qty: {
              name: "Quantity in Kit",
              col_length: 5
            },
            available_inv: {
              name: "Available Inv",
              editable: false,
              col_length: 5
            },
            qty_on_hand: {
              name: "QTY On Hand",
              col_length: 5,
              editable: false
            },
            status: {
              name: "Status",
              col_length: 5,
              transclude: "<span class='label label-default' ng-class=\"{" +
              "'label-success': row.product_status == 'active', " +
              "'label-info': row.product_status == 'new' }\">" +
              "{{row.product_status}}</span>",
              editable: false
            },
            packing_order: {
              name: "Packing Order",
              col_length: 5
            },
          }
        };
        myscope.add_hotkeys();

        if (product_id) {
          myscope.update_state = false;
          myscope.product_single_details(product_id, true);
        } else {
          myscope.update_state = true;
          myscope.product_single_details($stateParams.product_id, true);
        }
        $modalInstance.result.then(scope.update, scope.update);
      };
      myscope.init();


      //scope.$on("alias-modal-selected",scope._add_alias_product);
      //$('.icon-question-sign').popover({trigger: 'hover focus'});
      scope.$emit("products-modal-loading-complete", {identifier: scope.custom_identifier});
      scope.$on("products-modal-loading-complete", function (event, args) {
        if (args.identifier !== scope.custom_identifier) {
          event.stopPropagation();
        }
      });

    }]);
