groovepacks_controllers.
  controller('productsCtrl', ['$scope', '$http', '$timeout', '$stateParams', '$location', '$state', '$cookies', '$q', '$modal', 'products', '$rootScope', '$window',
    function ($scope, $http, $timeout, $stateParams, $location, $state, $cookies, $q, $modal, products, $rootScope, $window) {
      //Definitions

      var myscope = {};
      /*
       * Public methods
       */

      myscope.datagrid_features = function(){
        msg = "<p><strong>There are a number of handy features in the order and product lists:</strong></p>" +
         "<p>Send to Scan and Pack - Ctrl-Click the order number in the orders list to send it to Scan and Pack</p>" +
         "<p>Right-Click to Edit - Right click fields directly in the grid to edit them.</p>" +
         "<p>Shift-Click to Select - Click a row in the grid to select it, then shift click another row to select it and all in between.</p>" +
         "<p>Show and Hide Columns - Right-Click the column header to select which columns should be visible</p>" +
         "<p>Sort by column - Click most columns to sort the data by that column</p>" +
         "<p>Sort by last modified - This is the default sort mode. To return to it just Shift-Click the column header.</p>" +
         "<p>Re-Order columns - Click and hold on a column header to pick it up and drag it to a new location.</p>"
        return msg;
      }

      $scope.load_page = function (direction) {
        var page = parseInt($state.params.page, 10);
        page = (typeof direction == 'undefined' || direction != 'previous') ? page + 1 : page - 1;
        return myscope.load_page_number(page);
      };

      $scope.select_all_toggle = function (val) {
        $scope.products.setup.select_all = !!val;
        myscope.invert(false);
        $scope.products.selected = [];
        for (var i = 0; i < $scope.products.list.length; i++) {
          $scope.products.list[i].checked = $scope.products.setup.select_all;
          if ($scope.products.setup.select_all) {
            myscope.select_single($scope.products.list[i]);
          }
        }
      };

      $scope.update_product_list = function (product, prop) {
        if(prop == 'barcode' && !product[prop] && product['status'] != 'active' /*if null*/){return}
        products.list.update_node({
          id: product.id,
          var: prop,
          value: product[prop]
        }).then(function () {
          myscope.get_products()
        });
      };

      $scope.create_product = function () {
        $scope.products.setup.search = '';
        products.single.create($scope.products).success(function (data) {
          if (data.status) {
            $state.params.filter = 'new';
            data.product.new_product = true;
            myscope.handle_click_fn(data.product);
          }
        });
      };

      //Setup options
      $scope.product_setup_opt = function (type, value) {
        myscope.common_setup_opt(type, value, 'product');
      };

      $scope.kit_setup_opt = function (type, value) {
        myscope.common_setup_opt(type, value, 'kit');
      };

      $scope.handlesort = function (value) {
        if(event.shiftKey){
          value = '';
          // To get the new orders always in DESC
          $scope.products.setup.order = 'ASC';
        }
        // Bug fixed for GROOV-1054
        myscope.common_setup_opt('sort', value, $scope.product_type/*'product'*/);
      };

      $scope.product_change_status = function (status) {
        $scope.products.setup.status = status;
        products.list.update('update_status', $scope.products).then(function (data) {
          $scope.products.setup.status = "";
          myscope.get_products();
        });
      };

      $scope.product_delete = function () {
        if (confirm('All orders with these product(s) will be put On Hold. Are you sure you want to delete the selected product(s)?')) {
          products.list.update('delete', $scope.products).then(function (data) {
            myscope.get_products();
          });
        }
      };

      $scope.product_receiving_label = function () {
        if($scope.products.selected.length>0){
          products.list.update('receiving_label', $scope.products).then(function (data) {
            myscope.get_products();
          });
        } else {
          products.list.select_notification();
        }
      };

      $scope.product_duplicate = function () {
        products.list.update('duplicate', $scope.products).then(function (data) {
          myscope.get_products();
        });
      };

      $scope.product_barcode = function () {
        if($scope.products.selected.length>0){
          products.list.update('barcode', $scope.products).then(function (data) {
            myscope.get_products();
          });
        } else {
          products.list.select_notification();
        }
      };

      $scope.backup_product_csv = function () {
        if($scope.products.selected.length>0){
          products.list.generate($scope.products).then(function (data) {
            myscope.get_products();
          });
        } else {
          products.list.select_notification();
        }
      };

      $scope.broken_image_export = function(){
        if($scope.products.selected.length>0){
          products.list.generate_broken_image($scope.products).then(function (data) {
            myscope.get_products();
          });
        } else {
          products.list.select_notification();
        }
      };

      $scope.setup_child = function (childStateParams) {
        $scope.product_type = childStateParams['type'];

        if (typeof childStateParams['type'] == 'undefined') {
          childStateParams['type'] = 'product';
        }
        myscope.select_tab(childStateParams['type']);
        if (typeof childStateParams['filter'] != 'undefined') {
          myscope.common_setup_opt('filter', childStateParams['filter'], childStateParams['type']);
        } else if (typeof childStateParams['search'] != 'undefined') {
          myscope.common_setup_opt('search', childStateParams['search'], childStateParams['type']);
        }
        if (typeof childStateParams['page'] == 'undefined' || childStateParams['page'] <= 0) {
          childStateParams['page'] = 1;
        }
        if ($scope.products.setup.select_all) {
          $scope.select_all_toggle(false);
        }
        return myscope.get_products(childStateParams['page']);
      };

      /*
       * Private methods
       */
      myscope.select_tab = function (type) {
        var index = (type == 'kit') ? 1 : ((type == 'inventory') ? 2 : 0);
        for (var i = 0; i < $scope.tabs.length; i++) {
          $scope.tabs[i].open = false;
        }
        $scope.tabs[index].open = true;
      };

      myscope.select_single = function (row) {
        products.single.select($scope.products, row);
      };

      myscope.select_pages = function (from, to, state) {
        products.list.select($scope.products, from, to, state);
      };

      myscope.invert = function (val) {
        $scope.products.setup.inverted = !!val;

        if ($scope.products.setup.inverted) {
          if ($scope.products.setup.select_all) {
            $scope.select_all_toggle(false);
          } else if ($scope.products.selected.length == 0) {
            $scope.select_all_toggle(true);
          }
        }
        myscope.update_selected_count();
      };

      myscope.show_selected = function () {
        if (!$scope.products.setup.select_all && $scope.products.selected.length > 0) {
          $modal.open({
            templateUrl: '/assets/views/modals/selections.html',
            controller: 'selectionModal',
            resolve: {
              selected_data: function () {
                return $scope.products.selected
              },
              selected_table_options: function () {
                return {
                  identifier: 'product_selections',
                  selectable: true,
                  selections: {
                    single_callback: myscope.select_single,
                    unbind: true
                  },
                  all_fields: {
                    name: {
                      name: "Item Name"
                    },
                    sku: {
                      name: "SKU"
                    },
                    barcode: {
                      name: "Barcode"
                    },
                    status: {
                      name: "Status",
                      transclude: "<span class='label label-default' ng-class=\"{" +
                      "'label-success': row[field] == 'active', " +
                      "'label-info': row[field] == 'new' }\">" +
                      "{{row[field]}}</span>"
                    }
                  }
                };
              }
            },
            size: 'lg'
          });
        }

      };

      myscope.load_page_number = function (page) {
        $scope.inventory_report_page = false;
        if (page > 0 && page <= Math.ceil($scope.gridOptions.paginate.total_items / $scope.gridOptions.paginate.items_per_page)) {
          if ($scope.products.setup.search == '') {
            var toParams = {};
            for (var key in $state.params) {
              if ($state.params.hasOwnProperty(key) && ['type', 'filter', 'product_id'].indexOf(key) != -1) {
                toParams[key] = $state.params[key];
              }
            }
            toParams['page'] = page;
            $state.go($state.current.name, toParams);
          }
          return myscope.get_products(page);
        } else {
          var req = $q.defer();
          req.reject();
          return req.promise;
        }
      };

      myscope.update_print_status = function (product) {
        $window.open('/products/' + product.id + '/generate_barcode_slip.pdf');
      };

      myscope.show_delete = function () {
        if ($state.params.filter == 'inactive') {
          return true;
        }
        return false;
      };

      //Constructor
      myscope.init = function () {
        //Public properties
        $scope.products = products.model.get();
        $scope.tabs = [
          //accordian product tab
          {open: true},
          //accordian kit tab
          {open: false},
          //accordian inventory tab
          {open: false}
        ];
        $scope.inventory_report_page = $state.params.inventory 
        if ($state.params.inventory == true){
          $scope.tabs = [{open: false},{open: false},{open: true}]
          $state.params.filter = 'active'
          $scope.page_type = $state.params.type 
        }
        //Private properties
        $scope.inventory_record_time = myscope.defaults()
        myscope.do_load_products = false;
        $scope._can_load_products = true;

        $http.get('/products/get_inventory_setting.json').success(function(data){
          $scope.inventory_report_toggle = data.inventory_report_toggle;
          $scope.inventory_report_settings = data.setting;
          $scope.inventory_report_products = data.products;
          $scope.inventory_record_time.start.time = $scope.inventory_report_settings.start_time
          $scope.inventory_record_time.end.time = $scope.inventory_report_settings.end_time 
        });

        // $scope.inventory_report_settings = products.single.get_inventory_setting();
        //Cache current page
        myscope.page_exists = -1;
        $scope.gridOptions = {
          identifier: 'products',
          dynamic_width: true,
          select_all: $scope.select_all_toggle,
          invert: myscope.invert,
          sort_func: $scope.handlesort,
          features: myscope.datagrid_features(),
          setup: $scope.products.setup,
          scrollbar: true,
          no_of_lines: 3,
          selections: {
            show_dropdown: true,
            single_callback: myscope.select_single,
            multi_page: myscope.select_pages,
            selected_count: 0,
            show: myscope.show_selected,
            show_delete: myscope.show_delete()
          },
          paginate: {
            show: true,
            //send a large number to prevent resetting page number
            total_items: 50000,
            current_page: $state.params.page,
            items_per_page: $scope.products.setup.limit,
            callback: myscope.load_page_number
          },
          show_hide: true,
          selectable: true,
          draggable: true,
          sortable: true,
          editable: {
            print_status: myscope.update_print_status,
            array: false,
            update: $scope.update_product_list,
            elements: {
              status: {
                type: 'select',
                options: [
                  {name: "Active", value: 'active'},
                  {name: "Inactive", value: 'inactive'},
                  {name: "New", value: 'new'}
                ]
              },
              qty_on_hand: {
                type: 'number',
                min: 0
              }
            },
            functions: {
              name: myscope.handle_click_fn
            }

          },         
          all_fields: {
            image: {
              name: "Image",
              editable: false,
              col_length: 15,
              transclude: '<div ng-click="options.editable.functions.name(row,$event)" class="pointer single-image"><img class="img-responsive" ng-src="{{row.image}}" /></div>'
            },
            name: {
              name: "Item Name",
              hideable: false,
              col_length: 20,
              transclude: '<a href="" ng-click="options.editable.functions.name(row,$event)" tooltip="{{row[field]}}" tooltip-placement="{{set_position(row, rows)}}">{{row[field] | cut:true:(25*options.no_of_lines)}}</a>'
            },
            sku: {
              name: "SKU",
              col_length: 20
            },
            status: {
              name: "Status",
              col_length: 5,
              transclude: "<span class='label label-default' ng-class=\"{" +
              "'label-success': row[field] == 'active', " +
              "'label-info': row[field] == 'new' }\">" +
              "{{row[field]}}</span>"
            },
            barcode: {
              col_length: 20,
              name: "Barcode"
            },
            location_primary: {
              name: "Primary Location",
              col_length: 20,
              class: "span3"
            },
            store_name: {
              name: "Store",
              editable: false
            },
            qty_on_hand: {
              name: "QoH",
              col_length: 7
            },
            available_inv: {
              name: "Avbl Inv",
              editable: false
            },
            cat: {
              name: "Category",
              col_length: 15,
              hidden: true
            },
            location_secondary: {
              name: "Secondary Location",
              col_length: 20,
              class: "span3",
              hidden: true
            },
            location_tertiary: {
              name: "Tertiary Location",
              col_length: 20,
              class: "span3",
              hidden: true
            },
            print_barcode: {
              name: "Print Barcode",
              editable: false,
              hidden: true,
              col_length: 20,
              transclude: "<a class='groove-button label label-default' groov-click=\"options.editable.print_status(row)\" href=\"\">" +
              "&nbsp;&nbsp;<i class=\"glyphicon glyphicon-print icon-large white\"></i>&nbsp;&nbsp;</a>"
            },
            location_name: {
              name: "Warehouse Name",
              class: "span3",
              editable: false,
              hidden: true
            }
          }
        };

        $scope.newoptions = {
          scrollbar: true,
          no_of_lines: 1,
          selectable: true,
          functions: {
            name: myscope.handle_click_func
          },
          all_fields: {
            is_locked: {
              name: "",
              transclude: '<i tooltip="The default reports can not be modified" class="fa fa-lock" aria-hidden="true" ng-if="row.is_locked==true"></i>'
            },
            name: {
              name: "Report Name",
              col_length: 25,
              editable: false
            },
            no_of_items: {
              name: "Number of items",
              col_length: 15,
              editable: false
            },
            scheduled: {
              name: "Scheduled",
              col_length: 5,
              transclude: '<div toggle-switch ng-model="row.scheduled" ng-click="options.functions.name(row, event, undefined)"></div>'
            },
            type: {
              name: "Report Type",
              editable: false,
              col_length: 5,
              transclude: '<div class="controls dropdown"> <button class="dropdown-toggle groove-button"> {{row.type==true ? "Orders Containing SKU Report" : "Inventory Projection Report"}} <span class="caret"></span> </button> <ul class="dropdown-menu" role="menu"> <li><a class="dropdown-toggle" ng-click="options.functions.name(row, event, true)">Orders Containing SKU Report</a></li> <li><a class="dropdown-toggle" ng-click="options.functions.name(row, event, false)">Inventory Projection Report</a></li> </ul> </div>'
            },
          }
        };

        myscope.initializing = true;

        //Register watchers
        $scope.$watch('products.setup.search', function () {
          if (myscope.initializing) {
            $timeout(function() { myscope.initializing = false; });
          } else {
            if ($scope.productFilterTimeout) $timeout.cancel($scope.productFilterTimeout);

            if ($scope.products.setup.select_all) {
              $scope.select_all_toggle(false);
            }
            $scope.productFilterTimeout = $timeout(function() {
              myscope.get_products();
            }, 500); // delay 500 ms
          }
        });
        $scope.$watch('_can_load_products', myscope.can_do_load_products);

        $scope.product_modal_closed_callback = myscope.get_products;
        $scope.$watch('products.selected', myscope.update_selected_count, true);
        $rootScope.$on('bulk_action_finished', function () {
          myscope.get_products();
        });
        //$("#product-search-query").focus();
      };

      $scope.product_inventory_record = function (type, exceptions, id) {
        var inventory_products_modal = $modal.open({
          templateUrl: '/assets/views/modals/product/inventory_record.html',
          controller: 'inventoryRecordModal',
          size: 'lg',
          resolve: {
            type: function () {return type},
            exceptions: function () {return exceptions},
            id: function () {return id;},
            selected_report: function(){ return null;}  
          }
        });
        inventory_products_modal.result.then(function (data) {
          myscope.add_inventory_product(data);
          myscope.get_settings();
        });
      };

      myscope.get_settings =function(){
        $http.get('/products/get_inventory_setting.json').success(function(data){
          $scope.inventory_report_settings = data.setting;
          $scope.inventory_report_products = data.products;
          // myscope.init();
        }); 
      }

      $scope.update_inventory_record = function (type, exceptions, id, selected_report) {
        var selected_ids = [];
        for (var i = 0; i < Object.keys(selected_report).length; i++) {
          if (selected_report[i].checked && (selected_report[i].is_locked == false)) {
            selected_ids.push(selected_report[i]);
          }
        }
        first_selected_obj = selected_ids[0]
        if (first_selected_obj != undefined) {
          var inventory_products_modal = $modal.open({
            templateUrl: '/assets/views/modals/product/inventory_record.html',
            controller: 'inventoryRecordModal',
            size: 'lg',
            resolve: { 
              type: function () { return type },
              exceptions: function () { return exceptions },
              id: function () { return id; },
              selected_report: function(){ return first_selected_obj;},
            }
          });
          inventory_products_modal.result.then(function (data) {
            data["report_id"] = first_selected_obj.id
            myscope.add_inventory_product(data);
            myscope.get_settings();
          });
        } else {
          $scope.notify('The default reports can not be modified');
        }
      };

      myscope.handle_click_func = function(row, event, type){
        if (type != undefined){
          row.type = type;
        }
        myscope.add_inventory_product(row);
      };

      myscope.add_inventory_product = function(data){
        if (typeof data != "undefined") {
          products.list.update_record(data);
        }
      };

      myscope.get_products = function (page) {

        // Don't send page no to skip cached data
        if(typeof page != 'undefined' && myscope.page_exists.toString() === page.toString()){
          return;
        }

        if (typeof page == 'undefined') {
          page = $state.params.page;
        }

        $scope.gridOptions.selections.show_delete = myscope.show_delete();
        if ($scope._can_load_products) {
          $scope._can_load_products = false;
          return products.list.get($scope.products, page).success(function (response) {
            $scope.gridOptions.paginate.total_items = products.list.total_items($scope.products);
            if ($scope.gridOptions.paginate.current_page != page) {
              $scope.gridOptions.paginate.current_page = page;
            }
            myscope.update_selected_count();
            myscope.update_table_accordian_width();
            $scope._can_load_products = true;
            myscope.page_exists = page;
          }).error(function () {
            $scope._can_load_products = true;
          });
        } else {
          myscope.do_load_products = page;
          var req = $q.defer();
          req.resolve();
          return req.promise;
        }

      };

      myscope.update_table_accordian_width = function () {
        if($('.accordion-parent').width() > 200){
          //$('.table-parent').width($('.table-parent').first().width() + $('.accordion-parent').width() - 170);
          $('.table-parent').css('width', '100%');
          $('.accordion-parent').width(170)
        }
      }

      myscope.update_selected_count = function () {
        if ($scope.products.setup.inverted && $scope.gridOptions.paginate.show) {
          $scope.gridOptions.selections.selected_count = $scope.gridOptions.paginate.total_items - $scope.products.selected.length;
        } else {
          $scope.gridOptions.selections.selected_count = $scope.products.selected.length;
        }
      };

      myscope.common_setup_opt = function (type, value, selector) {
        products.setup.update($scope.products.setup, type, value);
        $scope.products.setup.is_kit = (selector == 'kit') ? 1 : 0;
        myscope.get_products();
      };

      myscope.handle_click_fn = function (row, event) {
        if (typeof event != 'undefined') {
          event.stopPropagation();
        }

        var toState = 'products.type.filter.page.single';
        var toParams = {};
        for (var key in $state.params) {
          if (['type', 'filter', 'page'].indexOf(key) != -1) {
            toParams[key] = $state.params[key];
          }
        }
        toParams.product_id = row.id;
        if (row.new_product) {
          toParams.new_product = true;
        }
        $scope.select_all_toggle(false);
        $state.go(toState, toParams);

      };
      //Watcher ones
      myscope.can_do_load_products = function () {
        if ($scope._can_load_products && myscope.do_load_products) {
          myscope.get_products(myscope.do_load_products);
          myscope.do_load_products = false;
        }
      };

      myscope.defaults = function () {
        return {
          start: {
            open: false,
            time: new Date()
          },
          end: {
            open: false,
            time: new Date()
          }
        }
      };

      $scope.recount_or_receive_inventory = function () {
        $modal.open({
          templateUrl: '/assets/views/modals/product/inventory.html',
          controller: 'inventoryModal',
          size: 'lg'
        });
      };

      $scope.inventory_report = function(){
        $scope.inventory_report_page = true;
      };

      $scope.open_picker = function (event, object) {
        event.preventDefault();
        event.stopPropagation();
        object.open = true;
      };

      $scope.remove_report = function (inv_products) {
        var selected_ids = [];
        //console.log(scope.products.single.productkitskus);
        arr_length = Object.keys(inv_products).length;
        for (var i = 0; i < arr_length; i++) {
          if (inv_products[i].checked && (inv_products[i].is_locked == false)) {
            selected_ids.push(inv_products[i].id);
          }
        }
        if (selected_ids.length != 0){
          products.list.remove_inventory_record(selected_ids).then(function (data) {
            $scope.inventory_report_products = {};
            myscope.get_settings();
          });
        } else {
          $scope.notify('The default reports can not be modified');
        }
      };

      $scope.generate_report = function(selected_report){
        var selected_ids = [];
        for (var i = 0; i < Object.keys(selected_report).length; i++) {
          if (selected_report[i].checked) {
            selected_ids.push(selected_report[i].id);
          };
        };
        if (selected_ids.length != 0){
          products.list.generate_inventory_record(selected_ids);
        } else{
          $scope.notify('Please select report');
        }

      };

      $scope.update_inventory_report_settings = function () {
        $scope.show_button = false;
        products.single.update_inventory_settings($scope.inventory_report_settings);
      };

      $scope.change_opt = function(option){
        products.single.update_record_option(option);
        myscope.get_settings();
      }

      $scope.download_csv = function () {
        if ($scope.inventory_report_settings.start.time <= $scope.inventory_report_settings.end.time) {
          // $window.open('/exportsettings/order_exports?start=' + $scope.exports.start.time + '&end=' + $scope.exports.end.time);
          $http.get('/exportsettings/order_exports?start=' + $scope.inventory_report_settings.start.time + '&end=' + $scope.inventory_report_settings.end.time);
          //$scope.notify('It will be emailed to ' + $scope.export_settings.single.order_export_email, 1);
        } else {
          $scope.notify('Start time can not be after End time');
        }
      };

      //Definitions end above this line
      /*
       * Initialization
       */
      //Main code ends here. Rest is function calls etc to init
      myscope.init();
    }]);
