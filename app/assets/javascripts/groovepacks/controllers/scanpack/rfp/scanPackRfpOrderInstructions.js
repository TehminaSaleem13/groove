groovepacks_controllers.controller('scanPackRfpOrderInstructions', ['$scope', '$modalInstance', '$timeout',
  'order_data', 'confirm', 'scan_pack_settings', 'scanPack',
  function ($scope, $modalInstance, $timeout, order_data, confirm,
            scan_pack_settings, scanPack) {
    var myscope = {};

    myscope.init = function () {
      $scope.order = order_data;
      $scope.scan_pack_settings = scan_pack_settings;
      $timeout($scope.focus_search, 200);
      $scope.code = {};
      $scope.code.confirmation = '';
    };

    $scope.check_order_confirm = function (event) {
      if (event.which != 13) return;
      $scope.update('ok-enter-key');
    };

    $scope.update = function (reason) {
      if (reason == 'ok-enter-key') {
        scanPack.order_instruction($scope.order.id, $scope.code.confirmation).then(function (data) {
          $scope.code.confirmation = "";
          $timeout($scope.focus_search, 200);
          if (data.data.confirmed) {
            $modalInstance.close("finished");
            confirm();
          }
        });
      }
    };

    $scope.ok = function () {
      $modalInstance.close("ok-button-click");
    };
    $scope.cancel = function () {
      $modalInstance.dismiss("cancel-button-click");
    };

    myscope.init();
  }]);
