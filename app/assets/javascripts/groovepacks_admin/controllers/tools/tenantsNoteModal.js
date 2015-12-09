groovepacks_admin_controllers.
  controller('tenantsNoteModal', ['$scope', '$http', '$timeout', '$stateParams', '$location', '$state', '$cookies', '$modal', '$modalInstance', 'tenant_data', 'tenants',
    function ($scope, $http, $timeout, $stateParams, $location, $state, $cookies, $modal, $modalInstance, tenant_data, tenants) {
      //Definitions

      var myscope = {};
      /*
       * Public methods
       */

      $scope.ok = function () {
        $modalInstance.close("ok-button-click");
        tenants.single.update($scope.tenants);
      };

      $scope.cancel = function () {
        $modalInstance.dismiss("cancel-button-click");
      };

      myscope.init = function () {
        $scope.tenants = tenant_data;
        $scope.tenants.single.note = $scope.tenants.single.basicinfo.note
      };

      myscope.init();

    }]);
