groovepacks_controllers.
  controller('productsCtrl', ['$scope', '$http', '$timeout', '$stateParams', '$location', '$state', '$cookies', '$q', '$modal', 'products', '$rootScope',
    function ($scope, $http, $timeout, $stateParams, $location, $state, $cookies, $q, $modal, products, $rootScope) {
      //Definitions

      var myscope = {};
      /*
       * Public methods
       */
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

      $scope.handlesort = function (predicate) {
        myscope.common_setup_opt('sort', predicate, 'product');
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

      $scope.setup_child = function (childStateParams) {
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


        //Private properties

        myscope.do_load_products = false;
        $scope._can_load_products = true;
        $scope.gridOptions = {
          identifier: 'products',
          dynamic_width: true,
          select_all: $scope.select_all_toggle,
          invert: myscope.invert,
          sort_func: $scope.handlesort,
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
              transclude: '<a href="" ng-click="options.editable.functions.name(row,$event)" tooltip="{{row[field]}}">{{row[field].chunk(25).join(" ") | cut:true:(25*options.no_of_lines)}}</a>'
            },
            sku: {
              name: "SKU",
              col_length: 20
            },
            status: {
              name: "Status",
              col_length: 10,
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
              col_length: 20,
              editable: false
            },
            qty_on_hand: {
              name: "QoH",
              col_length: 7,
              sortable: false
            },
            available_inv: {
              name: "Avbl Inv",
              col_length: 7,
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
            location_name: {
              name: "Warehouse Name",
              col_length: 20,
              class: "span3",
              editable: false,
              hidden: true
            }
          }
        };

        //Register watchers
        $scope.$watch('products.setup.search', function () {
          if ($scope.products.setup.select_all) {
            $scope.select_all_toggle(false);
          }
          myscope.get_products(1);
        });
        $scope.$watch('_can_load_products', myscope.can_do_load_products);

        $scope.product_modal_closed_callback = myscope.get_products;
        $scope.$watch('products.selected', myscope.update_selected_count, true);
        $rootScope.$on('bulk_action_finished', function () {
          myscope.get_products();
        });
        //$("#product-search-query").focus();
      };

      myscope.get_products = function (page) {

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
            $scope._can_load_products = true;
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
        myscope.get_products(1);
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

      $scope.recount_or_receive_inventory = function () {
        $modal.open({
          templateUrl: '/assets/views/modals/product/inventory.html',
          controller: 'inventoryModal',
          size: 'lg'
        });
      };


      //Definitions end above this line
      /*
       * Initialization
       */
      //Main code ends here. Rest is function calls etc to init
      myscope.init();
    }]);
