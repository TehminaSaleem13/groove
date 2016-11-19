groovepacks_controllers.
  controller('orderExportCtrl', ['$scope', '$http', '$timeout', '$location', '$state', '$cookies', '$window', 'exportsettings',
    function ($scope, $http, $timeout, $location, $state, $cookies, $window, exportsettings) {
      var myscope = {};
      myscope.defaults = function () {
        return {
          start: {
            open: false,
            time: new Date()
          },
          end: {
            open: false,
            time: new Date()
          }
        }
      };

      myscope.init = function () {
        $scope.exports = myscope.defaults();
        $scope.setup_page('backup_restore', 'order_export');
        $scope.export_settings = exportsettings.model.get();
        exportsettings.single.get($scope.export_settings);
      };

      $scope.open_picker = function (event, object) {
        event.preventDefault();
        event.stopPropagation();
        object.open = true;
      };

      $scope.update_export_settings = function () {
        $scope.show_button = false;
        exportsettings.single.update($scope.export_settings);
      };

      $scope.change_option = function (key, value) {
        $scope.export_settings.single[key] = value;
        $scope.update_export_settings();
      };

      $scope.download_csv = function () {
        if ($scope.exports.start.time <= $scope.exports.end.time) {
          // $window.open('/exportsettings/order_exports?start=' + $scope.exports.start.time + '&end=' + $scope.exports.end.time);
          $http.get('/exportsettings/order_exports?start=' + $scope.exports.start.time + '&end=' + $scope.exports.end.time);
          $scope.notify('Your request has been queued', 1);
        } else {
          $scope.notify('Start time can not be after End time');
        }
      };

      myscope.init();
    }]);
