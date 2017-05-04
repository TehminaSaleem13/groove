groovepacks_controllers.
  controller('exportNotificationCtrl', ['$scope', '$http', '$timeout', '$stateParams', '$location', '$state', '$modal',
    '$modalStack', '$previousState', '$cookies', '$modalInstance',  'notification', 'settings_data',
    function ($scope, $http, $timeout, $stateParams, $location, $state, $modal, $modalStack, $previousState, $cookies, $modalInstance, notification, settings_data) {
    var myscope = {};

    myscope.init = function () {
      $scope.settings_data = settings_data;
      $scope.export_address = "";
    };

    $scope.update_export_address = function(email){
      if (email != "" && email.includes("@")){
        $scope.settings_data.order_export_email = email;
        $http.put('/exportsettings/update_export_settings.json', $scope.settings_data);
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
