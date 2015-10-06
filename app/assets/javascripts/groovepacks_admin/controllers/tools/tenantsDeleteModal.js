groovepacks_controllers.
  controller('tenantsDeleteModal', ['$scope', '$http', '$timeout', '$stateParams', '$location', '$state', '$cookies', '$modal', '$modalInstance', 'tenant_data', 'deletion_type', 'tenants',
    function ($scope, $http, $timeout, $stateParams, $location, $state, $cookies, $modal, $modalInstance, tenant_data, deletion_type, tenants) {
      //Definitions

      var myscope = {};
      /*
       * Public methods
       */

      $scope.ok = function () {
        $modalInstance.close("ok-button-click");
        tenants.single.delete($scope.tenants.single.basicinfo.id, deletion_type);
      };

      $scope.cancel = function () {
        $modalInstance.dismiss("cancel-button-click");
      };

      myscope.init = function () {
        $scope.tenants = tenant_data;
        $scope.tenants.deletion_type = deletion_type;
      };

      myscope.init();

    }]);
