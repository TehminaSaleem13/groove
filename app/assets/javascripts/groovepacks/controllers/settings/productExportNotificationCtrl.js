groovepacks_controllers.
  controller('productExportNotificationCtrl', ['$scope', '$http', '$timeout', '$stateParams', '$location', '$state', '$modal',
    '$modalStack', '$previousState', '$cookies', '$modalInstance',  'notification', 'generalsettings', 'settings_data',
    function ($scope, $http, $timeout, $stateParams, $location, $state, $modal, $modalStack, $previousState, $cookies, $modalInstance, notification, generalsettings, settings_data) {
    var myscope = {};

    myscope.init = function () {
      $scope.settings_data = settings_data;
      $scope.system_notification = "";
    };

    $scope.update_sys_notification = function(email){
      if (email != "" && email.includes("@")){
        $scope.settings_data.email_address_for_packer_notes = email;
        $http.put('/settings/update_email_address_for_packer_notes.json', {email: email});
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
