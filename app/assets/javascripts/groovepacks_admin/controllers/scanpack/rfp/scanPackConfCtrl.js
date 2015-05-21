groovepacks_admin_controllers.
    controller('scanPackConfCtrl', [ '$scope', '$http', '$timeout', '$stateParams', '$location', '$state', '$cookies','$q','scanPack',
        function( $scope, $http, $timeout, $stateParams, $location, $state, $cookies, $q, scanPack) {
            var myscope = {};
            myscope.init = function() {
                $scope.rfpinit().then(function(){
                    if($scope.data.order.status == "awaiting") {
                        $state.go('scanpack.rfp.default',{order_num:$stateParams.order_num});
                    }
                   $scope.set('title',"Scan Confirmation Code or Scan a new order");
                });
            };
            $scope.$on('reload-scanpack-state',myscope.init);
            myscope.init();
}]);
