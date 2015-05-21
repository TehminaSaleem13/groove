groovepacks_controllers.controller('productsFilterCtrl', [ '$scope', '$http', '$timeout', '$stateParams', '$location',
'$state', '$cookies','products','inventory_manager', 'warehouses',
function( $scope, $http, $timeout, $stateParams, $location, $state, $cookies,products,
          inventory_manager, warehouses) {
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
