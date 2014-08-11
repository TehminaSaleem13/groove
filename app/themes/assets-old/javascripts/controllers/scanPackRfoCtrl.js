groovepacks_controllers.
    controller('scanPackRfoCtrl', [ '$scope', '$http', '$timeout', '$stateParams', '$location', '$state', '$cookies','orders',
        function( $scope, $http, $timeout, $stateParams, $location, $state, $cookies, orders) {
            var myscope = {};
            myscope.init = function() {
                $scope.init();
                $scope.set('title', "Ready for Order Scan");
                $scope.set('order', {});

            }
            //Initialize
            $scope.$on('reload-scanpack-state',myscope.init);
            myscope.init();
}]);
