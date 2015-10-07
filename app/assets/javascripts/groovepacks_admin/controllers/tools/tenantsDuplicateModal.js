groovepacks_admin_controllers.
  controller('tenantsDuplicateModal', ['$scope', '$http', '$timeout', '$stateParams', '$location', '$state', '$cookies', '$modal', '$modalInstance', 'tenant_data', 'tenants',
    function ($scope, $http, $timeout, $stateParams, $location, $state, $cookies, $modal, $modalInstance, tenant_data, tenants) {
      //Definitions

      var myscope = {};
      /*
       * Public methods
       */

      $scope.ok = function () {
        $modalInstance.close("ok-button-click");
        // tenants.single.delete($scope.tenants.single.basicinfo.id, deletion_type);
      };

      $scope.cancel = function () {
        $scope.tenants.duplicate_name = '';
        $modalInstance.dismiss("cancel-button-click");
      };

      myscope.init = function () {
        $scope.tenants = tenant_data;
      };

      myscope.init();

    }]);
