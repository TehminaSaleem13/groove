groovepacks_controllers.
    controller('scanPackRecordingCtrl', [ '$scope', '$http', '$timeout', '$stateParams', '$location', '$state', '$cookies','orders','scanPack',
        function( $scope, $http, $timeout, $stateParams, $location, $state, $cookies, orders, scanPack) {
            var myscope = {};
            myscope.init = function() {
                $scope.rfpinit().then(function(){
                    $scope.set('title',"Scan Tracking number for Order "+ $stateParams.order_num+"");
                    if($scope.data.order.status != 'awaiting' || $scope.data.order.unscanned_items.length > 0) {
                        $state.go('scanpack.rfp.default',{order_num:$stateParams.order_num});
                    }
                });

            }
            $scope.$on('reload-scanpack-state',myscope.init);
            myscope.init();
        }]);
