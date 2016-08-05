groovepacks_admin_controllers.
  controller('tenantsSingleModal', ['$scope', '$http', '$timeout', '$stateParams', '$location', '$state', '$cookies', '$modal', '$modalInstance', 'hotkeys', 'tenant_data', 'load_page', 'tenant_id', 'tenants',
    function ($scope, $http, $timeout, $stateParams, $location, $state, $cookies, $modal, $modalInstance, hotkeys, tenant_data, load_page, tenant_id, tenants) {
      //Definitions

      var myscope = {};
      /*
       * Public methods
       */

      $scope.ok = function () {
        $modalInstance.close("ok-button-click");
      };

      $scope.cancel = function () {
        $modalInstance.dismiss("cancel-button-click");
      };

      $scope.update = function (reason) {
        hotkeys.del('up');
        hotkeys.del('down');
        if (reason == "cancel-button-click" || reason == "ok-button-click") {
          myscope.rollback();
        }
      };

      $scope.update_access_restrictions = function () {
        tenants.single.update_access($scope.tenants).then(function () {
          myscope.load_item($scope.tenants.current);
        });
      };

      $scope.allowinventory_pull_push_all = function () {
        tenants.single.update_access($scope.tenants).then(function () {
          myscope.load_item($scope.tenants.current);
        });
      };

      $scope.delete_orders = function () {
        $scope.delete('orders');
      };

      $scope.delete_products = function () {
        $scope.delete('products');
      };

      $scope.delete_orders_and_products = function () {
        $scope.delete('both');
      };

      $scope.delete_all = function () {
        $scope.delete('all');
      };

      $scope.delete = function (type) {
        myscope.tenant_obj = $modal.open({
          templateUrl: '/assets/admin_views/modals/tenants/delete.html',
          controller: 'tenantsDeleteModal',
          size: 'md',
          resolve: {
            tenant_data: function () {
              return $scope.tenants
            },
            load_page: function () {
              return function () {
                var req = $q.defer();
                req.reject();
                return req.promise;
              };
            },
            deletion_type: function () {
              return type;
            }
          }
        });
        myscope.tenant_obj.result.finally(function () {
          myscope.load_item($scope.tenants.current);
        });
      };

      myscope.rollback = function () {
        myscope.single = {};
        angular.copy($scope.tenants.single, myscope.single);
      };

      myscope.tenant_single_details = function (id) {
        for (var i = 0; i < $scope.tenants.list.length; i++) {
          if ($scope.tenants.list[i].id == id) {
            $scope.tenants.current = parseInt(i);
            break;
          }
        }

        tenants.single.get(id, $scope.tenants).success(function (data) {
        });
      };

      myscope.down_key = function (event) {
        event.preventDefault();
        event.stopPropagation();
        if ($scope.tenants.current < $scope.tenants.list.length - 1) {
          myscope.load_item($scope.tenants.current + 1);
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
        if ($scope.tenants.current > 0) {
          myscope.load_item($scope.tenants.current - 1);
        } else {
          load_page('previous').then(function () {
            myscope.load_item($scope.tenants.list.length - 1);
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
          hotkeys.bindTo($scope).add({
            combo: 'up',
            description: 'Previous tenant',
            callback: myscope.up_key
          })
            .add({
              combo: 'down',
              description: 'Next tenant',
              callback: myscope.down_key
            }).add({
              combo: 'esc',
              description: 'Save and close modal',
              callback: function () {
              }
            });
        }, 2000);
      };

      myscope.load_item = function (id) {
        myscope.tenant_single_details($scope.tenants.list[id].id);
        if (myscope.update_state) {
          var newStateParams = angular.copy($stateParams);
          newStateParams.tenant_id = "" + $scope.tenants.list[id].id;
          $state.go($state.current.name, newStateParams);
        }
      };

      myscope.init = function () {

        $scope.tenants = tenant_data;

        myscope.add_hotkeys();
        if (tenant_id) {
          myscope.update_state = false;
          myscope.tenant_single_details(tenant_id);
        } else {
          myscope.update_state = true;
          myscope.tenant_single_details($stateParams.tenant_id);
        }
        ;
        $modalInstance.result.then($scope.update, $scope.update);
      };

      myscope.init();

    }]);
