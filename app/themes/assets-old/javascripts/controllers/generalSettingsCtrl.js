groovepacks_controllers. 
controller('generalSettingsCtrl', [ '$scope', '$http', '$timeout', '$location', '$state', '$cookies',
	'generalsettings', function( $scope, $http, $timeout, $location, $state, $cookies, generalsettings) {

    var myscope = {};


    myscope.init = function() {
        $http.get('/home/userinfo.json').success(function(data){
            $scope.username = data.username;
        });
        $scope.current_page = "general";

        $scope.generalsettings = generalsettings.model.get();
        generalsettings.single.get($scope.generalsettings);

    }

    $scope.update_settings = function() {
        generalsettings.single.update($scope.generalsettings);
    }

	myscope.init();
}]);