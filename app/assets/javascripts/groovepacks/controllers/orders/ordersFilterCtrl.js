groovepacks_controllers.
    controller('ordersFilterCtrl', [ '$scope', '$http', '$timeout', '$stateParams', '$location', '$state', '$cookies','orders','$modal',
function( $scope, $http, $timeout, $stateParams, $location, $state, $cookies,orders,$modal) {
    //Definitions

    var myscope = {};
    /*
     * Public methods
     */


    myscope.init = function() {
        $scope.setup_child($stateParams);
    };

    myscope.init();

}]);
