groovepacks_controllers. 
controller('orderExportCtrl', [ '$scope', '$http', '$timeout', '$location', '$state', '$cookies', 'generalsettings', 'exportsettings',
function( $scope, $http, $timeout, $location, $state, $cookies, generalsettings, exportsettings) {
    var myscope = {};

    myscope.init = function() {
        $scope.setup_page('backup_restore','order_export');
        $scope.export_settings = exportsettings.model.get();
        exportsettings.single.get($scope.export_settings);
    };

    $scope.update_export_settings = function() {
        $scope.show_button = false;
        exportsettings.single.update($scope.export_settings);
    };

    $scope.change_option = function(key,value) {
        $scope.export_settings.single[key] = value;
        $scope.update_export_settings();
    };

    myscope.init();
}]);
