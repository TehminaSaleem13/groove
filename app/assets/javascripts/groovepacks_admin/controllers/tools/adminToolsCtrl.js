groovepacks_admin_controllers. 
controller('adminToolsCtrl', [ '$scope', '$http', '$timeout', '$location', '$state', '$cookies',
function( $scope, $http, $timeout, $location, $state, $cookies) {

    var myscope = {};


    myscope.init = function() {
        $scope.current_page = "show_admin_tools";
        $scope.tabs = [
                    {
                        page:'show_admin_tools',
                        open:true
                    }
                ];
    };
	myscope.init();
}]);
