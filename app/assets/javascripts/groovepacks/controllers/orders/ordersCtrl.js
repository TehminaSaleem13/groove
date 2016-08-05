groovepacks_controllers.
  controller('ordersCtrl', ['$scope', '$http', '$timeout', '$stateParams', '$location', '$state', '$cookies', '$q', 'orders', '$modal', 'generalsettings', '$rootScope',
    function ($scope, $http, $timeout, $stateParams, $location, $state, $cookies, $q, orders, $modal, generalsettings, $rootScope) {
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

      $scope.handlesort = function (value) {
        if(event.shiftKey){
          value = '';
          // To get the new orders always in DESC
          $scope.orders.setup.order = 'ASC';
        }
        myscope.order_setup_opt('sort', value);
      };

      $scope.load_page = function (direction) {
        var page = parseInt($state.params.page, 10);
        page = (typeof direction == 'undefined' || direction != 'previous') ? page + 1 : page - 1;
        return myscope.load_page_number(page);
      };

      $scope.select_all_toggle = function (val) {
        $scope.orders.setup.select_all = !!val;
        myscope.invert(false);
        $scope.orders.selected = [];
        for (var i = 0; i < $scope.orders.list.length; i++) {
          $scope.orders.list[i].checked = $scope.orders.setup.select_all;
          if ($scope.orders.setup.select_all) {
            myscope.select_single($scope.orders.list[i]);
          }
        }
      };
      $scope.update_order_list = function (order, prop) {
        orders.list.update_node({
          id: order.id,
          var: prop,
          value: order[prop]
        }).then(function () {
          $scope.orders.setup.status = "";
          myscope.get_orders();
        });

      };

      // $scope.get_user_confirmation = function(status) {
      //     myscope.order_obj= $modal.open({
      //         controller: 'ordersModal',
      //         templateUrl: '/assets/views/modals/order/confirmation.html',
      //         resolve: {
      //             order_data: function(){return $scope.orders;},
      //             status: function(){return status;}
      //         }
      //     });
      //     myscope.order_obj.result.then(function (data) {
      //         console.log(data);
      //         console.log("reloading the page");
      //         $scope.orders.setup.status = "";
      //         myscope.get_orders();
      //     });
      // };

      $scope.order_change_status = function (status) {
        if ($state.params.filter == "scanned") {
          $scope.orders.setup.reallocate_inventory = confirm("Should inventory deduct from available for allocation?");
        }
        $scope.orders.setup.status = status;
        orders.list.update('update_status', $scope.orders).then(function (data) {
          $scope.orders.setup.status = "";
          myscope.get_orders();
        });
      };


      $scope.order_delete = function () {
        orders.list.update('delete', $scope.orders).then(function (data) {
          myscope.get_orders();
        });
      };
      $scope.order_duplicate = function () {
        orders.list.update('duplicate', $scope.orders).then(function (data) {
          myscope.get_orders();
        });

      };
      $scope.generate_orders_pick_list = function () {
        orders.list.generate('pick_list', $scope.orders).then(
          function (data) {
          });
      };
      $scope.generate_orders_items_list = function () {
        orders.list.generate('items_list', $scope.orders);
      };
      $scope.generate_orders_packing_slip = function () {
        orders.list.generate('packing_slip', $scope.orders).then(
          function (data) {
          });
      };
      $scope.generate_orders_pick_list_and_packing_slip = function () {
        //call the pick_list and packing_slip actions separately, to get the pdfs.
        orders.list.generate('pick_list', $scope.orders).then(
          function (data) {
          });
        orders.list.generate('packing_slip', $scope.orders).then(
          function (data) {
          });
      };

      $scope.setup_child = function (childStateParams) {
        if (typeof childStateParams['filter'] != 'undefined') {
          orders.setup.update($scope.orders.setup, 'filter', childStateParams['filter']);
        } else if (typeof childStateParams['search'] != 'undefined') {
          orders.setup.update($scope.orders.setup, 'search', childStateParams['search']);
        }
        if (typeof childStateParams['page'] == 'undefined' || childStateParams['page'] <= 0) {
          childStateParams['page'] = 1
        }
        myscope.get_orders(childStateParams['page']);
      };

      /**
       * Private methods
       */
        //Constructor
      myscope.handle_click_fn = function (row, event) {
        if (typeof event != 'undefined') {
          event.stopPropagation();
        }
        if (event.ctrlKey || event.metaKey) {
          $state.go("scanpack.rfp.default", {order_num: row.ordernum});
        } else {
          var toState = 'orders.filter.page.single';
          var toParams = {};
          for (var key in $state.params) {
            if (['filter', 'page'].indexOf(key) != -1) {
              toParams[key] = $state.params[key];
            }
          }
          toParams.order_id = row.id;
          $scope.select_all_toggle(false);
          $state.go(toState, toParams);
        }
      };

      myscope.reset_change_status = function () {
        $scope.allow_status_changes.cancelled = $state.params.filter != "scanned";
        $scope.allow_status_changes.scanned = $state.params.filter != "cancelled"
      };

      myscope.update_selected_count = function () {
        if ($scope.orders.setup.inverted && $scope.gridOptions.paginate.show) {
          $scope.gridOptions.selections.selected_count = $scope.gridOptions.paginate.total_items - $scope.orders.selected.length;
        } else {
          $scope.gridOptions.selections.selected_count = $scope.orders.selected.length;
        }
      };

      myscope.select_single = function (row) {
        orders.single.select($scope.orders, row);
      };

      myscope.select_pages = function (from, to, state) {
        orders.list.select($scope.orders, from, to, state);
      };

      myscope.show_selected = function () {
        if (!$scope.orders.setup.select_all && $scope.orders.selected.length > 0) {
          $modal.open({
            templateUrl: '/assets/views/modals/selections.html',
            controller: 'selectionModal',
            resolve: {
              selected_data: function () {
                return $scope.orders.selected
              },
              selected_table_options: function () {
                return {
                  identifier: 'order_selections',
                  selectable: true,
                  selections: {
                    single_callback: myscope.select_single,
                    unbind: true
                  },
                  all_fields: {
                    ordernum: {
                      name: "Order #"
                    },
                    order_date: {
                      name: "Order Date",
                      transclude: "<span>{{row[field] | date:'EEEE MM/dd/yyyy hh:mm:ss a'}}</span>"
                    },
                    store_name: {
                      name: "Store"
                    },
                    status: {
                      name: "Status",
                      transclude: "<span class='label label-default' ng-hide=\"row[field] == 'onhold'\" ng-class=\"{" +
                      "'label-success': row[field] == 'awaiting', " +
                      "'label-danger': row[field] == 'serviceissue' }\">" +
                      "{{row[field]}}</span>" +
                      "<span class='label label-default label-warning' ng-show=\"row[field] == 'onhold'\">" +
                      "Action Required</span>"
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
          if ($scope.orders.setup.search == '') {
            var toParams = {};
            for (var key in $state.params) {
              if ($state.params.hasOwnProperty(key) && ['filter', 'order_id'].indexOf(key) != -1) {
                toParams[key] = $state.params[key];
              }
            }
            toParams['page'] = page;
            $state.go($state.current.name, toParams);
          }
          return myscope.get_orders(page);
        } else {
          var req = $q.defer();
          req.reject();
          return req.promise;
        }
      };

      myscope.order_setup_opt = function (type, value) {
        orders.setup.update($scope.orders.setup, type, value);
        myscope.get_orders();
      };

      myscope.get_orders = function (page) {

        // Don't send page no to skip cached data
        if(typeof page != 'undefined' && myscope.page_exists.toString() === page.toString()){
          return;
        }

        if (typeof page == 'undefined') {
          page = $state.params.page;
        }

        myscope.reset_change_status();
        if ($scope._can_load_orders) {
          $scope._can_load_orders = false;
          return orders.list.get($scope.orders, page).success(function (data) {
            $scope.gridOptions.paginate.total_items = orders.list.total_items($scope.orders);
            myscope.update_selected_count();
            myscope.update_table_accordian_width();
            $scope._can_load_orders = true;
            myscope.page_exists = page;
          }).error(function () {
            $scope._can_load_orders = true;
          });
        } else {
          myscope.do_load_orders = page;
          var req = $q.defer();
          req.resolve();
          return req.promise;
        }

      };

      myscope.update_table_accordian_width = function () {
        if($('.accordion-parent').width() > 200){
          $('.table-parent').width($('.table-parent').first().width() + $('.accordion-parent').width() - 170);
          $('.accordion-parent').width(170)
        }
      }

      myscope.invert = function (val) {
        $scope.orders.setup.inverted = !!val;

        if ($scope.orders.setup.inverted) {
          if ($scope.orders.setup.select_all) {
            $scope.select_all_toggle(false);
          } else if ($scope.orders.selected.length == 0) {
            $scope.select_all_toggle(true);
          }
        }
        myscope.update_selected_count();
      };

      var disable_global_edit = function() {
        return ($state.params.filter == 'scanned') ? true : false;
      }

      myscope.init = function () {
        //Public properties
        $scope.orders = orders.model.get();
        $scope.firstOpen = true;
        $scope.general_settings = generalsettings.model.get();
        $scope.allow_status_changes = {
          scanned: true,
          cancelled: true
        };

        $scope.disable_global_edit = disable_global_edit();
        generalsettings.single.get($scope.general_settings);

        //Private properties
        myscope.do_load_orders = false;
        $scope._can_load_orders = true;
        //Cache current page
        myscope.page_exists = -1;

        $scope.gridOptions = {
          identifier: 'orders',
          select_all: $scope.select_all_toggle,
          invert: myscope.invert,
          disable_global_edit: $scope.disable_global_edit,
          features: myscope.datagrid_features(),
          selections: {
            show_dropdown: true,
            single_callback: myscope.select_single,
            multi_page: myscope.select_pages,
            selected_count: 0,
            show: myscope.show_selected
          },
          draggable: true,
          dynamic_width: true,
          scrollbar: true,
          sortable: true,
          selectable: true,
          sort_func: $scope.handlesort,
          setup: $scope.orders.setup,
          show_hide: true,
          paginate: {
            show: true,
            //send a large number to prevent resetting page number
            total_items: 50000,
            current_page: $state.params.page,
            items_per_page: $scope.orders.setup.limit,
            callback: myscope.load_page_number
          },
          editable: {
            array: false,
            update: $scope.update_order_list,
            elements: {
              status: {
                type: 'select',
                options: [
                  {name: "Awaiting", value: 'awaiting'},
                  {name: "Service Issue", value: 'serviceissue'},
                  {name: "Cancelled", value: 'cancelled'},
                  {name: "Scanned", value: 'scanned'}
                ]
              },
              order_date: {
                type: 'datetime',
                min: 0
              }
            },
            functions: {
              ordernum: myscope.handle_click_fn
            }

          },
          all_fields: {
            ordernum: {
              name: "Order #",
              hideable: false,
              editable: false,
              copyable: true,
              //transclude:'<a href="" ng-click="function(ngModel.id,false,0,true)">{{ngModel.ordernum}}</a>',
              transclude: '<a href="" ng-click="options.editable.functions.ordernum(row,$event)" >{{row[field]}}</a>'
            },
            //tags: {
            //    name:"Tags",
            //    editable:false,
            //    sortable:false,
            //    transclude: '<div style="width:80px;">'+
            //        '<ul class="inline tag-list">'+
            //        '<li ng-repeat = "tag in row[field]">'+
            //        '<div class="tag-top-bottom-box" ng-show="tag.mark_place == 1"></div>'+
            //        '<div class="tagbox" ng-style="{background: tag.color}"></div>'+
            //        '<div class="tag-top-bottom-box" ng-show="tag.mark_place == 0"></div>'+
            //        '</li></ul></div>'
            //},
            store_name: {
              name: "Store",
              editable: false
            },
            notes: {
              name: "Notes",
              col_length: 20,
              enable_edit: true
            },
            order_date: {
              name: "Order Date",
              col_length: 12,
              transclude: '<span tooltip="{{row[field] | date:\'EEE MM/dd/yyyy hh:mm:ss a\'}}" tooltip-placement="{{set_position(row, rows)}}">{{row[field] | date:"EEE MM/dd/yyyy"}}</span>'
            },
            itemslength: {
              name: "Items",
              editable: false
            },
            recipient: {
              name: "Recipient"
            },
            status: {
              name: "Status",
              col_length: 13,
              transclude: "<span class='label label-default' ng-hide=\"row[field] == 'onhold'\" ng-class=\"{" +
              "'label-success': row[field] == 'awaiting', " +
              "'label-danger': row[field] == 'serviceissue' }\">" +
              "{{row[field]}}</span>" +
              "<span class='label label-default label-warning' ng-show=\"row[field] == 'onhold'\">" +
              "Action Required</span>"
            },
            email: {
              name: "Email",
              col_length: 20,
              hidden: true
            },
            tracking_num: {
              name: "Tracking Id",
              col_length: 25,
              hidden: true
            },
            city: {
              name: "City",
              hidden: true
            },
            state: {
              name: "State",
              hidden: true
            },
            postcode: {
              name: "Zip",
              col_length: 8,
              hidden: true
            },
            country: {
              name: "Country",
              hidden: true
            }
          }
        };

        if(custom_fields.length >= 1){
          if(custom_fields[0] && custom_fields[0].match(/\w+/)){
            $scope.gridOptions.all_fields.custom_field_one = {
              name: custom_fields[0],
              hidden: true,
              col_length: 20,
              enable_edit: true
            }
          }
          if(custom_fields[1] && custom_fields[1].match(/\w+/)){
            $scope.gridOptions.all_fields.custom_field_two = {
              name: custom_fields[1],
              hidden: true,
              col_length: 20,
              enable_edit: true
            }
          }
        }

        myscope.initializing = true;

        $scope.$watch('orders.setup.search', function () {
          if (myscope.initializing) {
            $timeout(function() { myscope.initializing = false; });
          } else {
            if ($scope.orderFilterTimeout) $timeout.cancel($scope.orderFilterTimeout);

            if ($scope.orders.setup.select_all) {
              $scope.select_all_toggle(false);
            }
            $scope.orderFilterTimeout = $timeout(function() {
              myscope.get_orders();
            }, 500); // delay 500 ms
          }
        });

        $scope.$watch('_can_load_orders', function () {
          if ($scope._can_load_orders) {
            if (myscope.do_load_orders) {
              myscope.get_orders(myscope.do_load_orders);
              myscope.do_load_orders = false;
            }
          }
        });
        $scope.$watch('orders.selected', myscope.update_selected_count, true);

        $scope.order_modal_closed_callback = myscope.get_orders;

        $rootScope.$on('bulk_action_finished', function () {
          myscope.get_orders();
        });

      };


      myscope.init();

    }]);
