groovepacks_controllers. 
controller('orderExportCtrl', [ '$scope', '$http', '$timeout', '$location', '$state', '$cookies', 'generalsettings', 'backupsettings',
function( $scope, $http, $timeout, $location, $state, $cookies, generalsettings, backupsettings) {
    var myscope = {};

    myscope.init = function() {
        $scope.setup_page('order_export');
        $scope.backup_settings = backupsettings.model.get();
        backupsettings.single.get($scope.backup_settings);
    };

    $scope.update_backup_settings = function() {
    	console.log("in update_backup_settings");
        $scope.show_button = false;
        backupsettings.single.update($scope.backup_settings);
    };

    myscope.init();
}]);
