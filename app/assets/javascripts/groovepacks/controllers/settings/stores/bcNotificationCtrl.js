groovepacks_controllers.
  controller('bcNotificationCtrl', ['$scope', '$http', '$timeout', '$stateParams', '$location', '$state', '$modal',
    '$modalStack', '$previousState', '$cookies', '$modalInstance', 'store_data', 'notification', 'generalsettings',
    function ($scope, $http, $timeout, $stateParams, $location, $state, $modal, $modalStack, $previousState, $cookies, $modalInstance, store_data, notification, generalsettings) {
      var myscope = {};

      myscope.init = function () {
        $scope.stores = store_data;
        $scope.system_notification = "";
      };

      $scope.update_sys_notification = function(email){
        if (email != ""){
          $scope.stores.import.product.status = "Import in progress";
          $scope.stores.import.product.status_show = true;
          $scope.stores.general_settings.email_address_for_packer_notes = email;
          generalsettings.single.update($scope.stores.general_settings);
          notification.notify("Email is succesfully updated.", 1);
          $modalInstance.close("ok-button-click");
        } else {
          notification.notify("Please update email", 0);
          $modalInstance.dismiss("cancel-button-click");  
        }
      }

      $scope.cancel = function () {
        $modalInstance.dismiss("cancel-button-click");
      };

      myscope.init();
    }]);
