groovepacks_controllers. 
controller('generalSettingsCtrl', [ '$scope', '$http', '$timeout', '$location', '$state', '$cookies',
	'generalsettings', function( $scope, $http, $timeout, $location, $state, $cookies, generalsettings) {

    var myscope = {};


    myscope.init = function() {
        $scope.setup_page('system','general');

        $scope.show_button = false;
        $scope.generalsettings = generalsettings.model.get();
        generalsettings.single.get($scope.generalsettings);

    };

    $scope.change_opt = function(key,value) {
        $scope.generalsettings.single[key] = value;
        $scope.update_settings();
    };

    $scope.update_settings = function() {
        $scope.show_button = false;
        generalsettings.single.update($scope.generalsettings);
    };

	myscope.init();
}]);
