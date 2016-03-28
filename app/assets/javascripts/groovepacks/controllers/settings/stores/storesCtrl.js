groovepacks_controllers.
  controller('storesCtrl', ['$scope', '$http', '$timeout', '$stateParams', '$location', '$state', '$cookies', 'stores', 'warehouses', 'notification', '$q',
    function ($scope, $http, $timeout, $stateParams, $location, $state, $cookies, stores, warehouses, notification, $q) {

      var myscope = {};

      $scope.select_all_toggle = function (val) {
        $scope.stores.setup.select_all = val;
        for (var store_index = 0; store_index <= $scope.stores.list.length - 1; store_index++) {
          $scope.stores.list[store_index].checked = $scope.stores.setup.select_all;
        }
      };


      $scope.store_change_status = function (status) {
        if($scope.check_if_not_selected()) {
          $scope.stores.setup.status = status;
          return stores.list.update('update_status', $scope.stores).then(function (data) {
            $scope.stores.setup.status = "";
            myscope.get_stores();
          });
        } else {
           stores.list.select_notification();
        }
      };

      $scope.check_if_not_selected = function () {
        var selected = false;
        for (var i = 0; i < $scope.stores.list.length; i++) {
          if ($scope.stores.list[i].checked === true) {
            selected = true;
            break;
          }
        }
        return selected;
      };

      $scope.store_delete = function () {
        if($scope.check_if_not_selected()) {
          $scope.stores.selected = 0;
          var result = $q.defer();
          for (var i = 0; i < $scope.stores.list.length; i++) {
            if ($scope.stores.list[i].checked) {
              $scope.stores.selected += 1;
            }
          }
          if ($scope.stores.selected === 0) {
            notification.notify('select a store to delete');
            result.resolve();
          } else if (confirm("Are you sure you want to delete the store" + (($scope.stores.selected == 1) ? "?" : "s?"))) {
            stores.list.update('delete', $scope.stores).then(function (data) {
              myscope.get_stores();
            }).then(result.resolve);
          } else {
            result.resolve();
          }
          return result.promise;
        } else {
           stores.list.select_notification();
        }
      };

      $scope.store_duplicate = function () {
        if($scope.check_if_not_selected()) {
          return stores.list.update('duplicate', $scope.stores).then(function (data) {
            myscope.get_stores();
          });
        } else {
           stores.list.select_notification();
        }
      };

      $scope.update_store_list = function (store, prop) {
        stores.list.update_node({
          id: store.id,
          var: prop,
          value: store[prop]
        }).then(function () {
          $scope.stores.setup.status = "";
          myscope.get_stores();
        });

      };


      myscope.handlesort = function (predicate) {
        myscope.store_setup_opt('sort', predicate);
      };

      myscope.store_setup_opt = function (type, value) {
        stores.setup.update($scope.stores.setup, type, value);
        myscope.get_stores();
      };

      myscope.get_stores = function () {
        return stores.list.get($scope.stores).then(function () {
          $scope.select_all_toggle();
          $scope.check_reset_links();
        });
      };

      myscope.init = function () {
        $scope.setup_page("show_stores");
        $scope.stores = stores.model.get();
        myscope.get_stores();
        $scope.gridOptions = {
          identifier: 'stores',
          select_all: $scope.select_all_toggle,
          draggable: false,
          sortable: true,
          selectable: true,
          sort_func: myscope.handlesort,
          setup: $scope.stores.setup,
          editable: {
            array: false,
            update: $scope.update_store_list,
            elements: {
              status: {
                type: 'select',
                options: [
                  {name: "Active", value: true},
                  {name: "Inactive", value: false}
                ]
              }
            }
          },
          all_fields: {
            name: {
              name: "Name",
              class: '',
              editable: false
            },
            status: {
              name: "Status",
              transclude: '<span class="label label-default" ng-class="{\'label-success\': row.status}">' +
              '<span ng-show="row.status" class="active">Active</span>' +
              '<span ng-hide="row.status" class="inactive">Inactive</span>' +
              '</span>',
              class: ''
            },
            store_type: {
              name: "Type",
              class: '',
              editable: false
            }

          }
        };
        if (typeof $scope.current_user.can != 'undefined' && $scope.current_user.can('add_edit_stores')) {
          $scope.gridOptions.all_fields.name.transclude = '<a ui-sref="settings.stores.single({storeid:row.id})"' +
            ' ng-click="$event.stopPropagation();">{{row[field]}}</a>';
        }

        $scope.$watch('stores.setup.search', myscope.get_stores);
        $scope.store_modal_closed_callback = function () {
          $timeout(myscope.get_stores, 100);
        };
      };

      myscope.init();

      //$scope.init();
    }]);
