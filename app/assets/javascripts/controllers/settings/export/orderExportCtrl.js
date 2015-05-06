groovepacks_controllers. 
controller('orderExportCtrl', [ '$scope', '$http', '$timeout', '$location', '$state', '$cookies', 'generalsettings', 'exportsettings',
function( $scope, $http, $timeout, $location, $state, $cookies, generalsettings, exportsettings) {
    var myscope = {};

    myscope.init = function() {
        $scope.setup_page('order_export');
        $scope.general_settings = generalsettings.model.get();
        generalsettings.single.get($scope.general_settings);
        console.log($scope.general_settings);
        $scope.export_settings = exportsettings.model.get();
        exportsettings.single.get($scope.export_settings);
    };

    $scope.update_export_settings = function() {
    	console.log("in update_export_settings");
        $scope.show_button = false;
        exportsettings.single.update($scope.export_settings);
    };

    $scope.change_option = function(key,value) {
    	$scope.export_settings.single[key] = value;
        $scope.update_export_settings();
    };

    myscope.init();
}]);
