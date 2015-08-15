groovepacks_controllers.
  controller('scanPackRfpAddNote', ['$scope', '$modalInstance', '$timeout', 'order_data', 'generalsettings', 'scanPack',
    function ($scope, $modalInstance, $timeout, order_data, generalsettings, scanPack) {
      var myscope = {};
      myscope.default_email = function () {
        return {
          show: false,
          send: false
        };
      };
      $scope.init = function () {
        $scope.email = myscope.default_email();
        $modalInstance.opened.finally(function () {
          $timeout(function () {
            $('#note_from_packer').focus();
            $timeout(function () {
              $scope.order = order_data;
            });
          }, 100);
        });
        $scope.general_settings = generalsettings.model.get();
        generalsettings.single.get($scope.general_settings).then(function () {
          $timeout(function () {
            $scope.email.show =
              (['always', 'never'].indexOf($scope.general_settings.single.send_email_for_packer_notes) == -1);
          });
        });
        $timeout(function () {
          $scope.$apply(function () {
            $scope.email.send = true;
          });

        });

      };


      $scope.update = function (reason) {
        if (reason != "cancel-button-click") {
          scanPack.add_note($scope.order.id, $scope.email.send, $scope.order.notes_fromPacker);
        }
      };
      $modalInstance.result.then($scope.update, $scope.update);

      $scope.ok = function () {
        $modalInstance.close("ok-button-click");
      };
      $scope.cancel = function () {
        $modalInstance.dismiss("cancel-button-click");
      };
      $scope.init();
    }]);
