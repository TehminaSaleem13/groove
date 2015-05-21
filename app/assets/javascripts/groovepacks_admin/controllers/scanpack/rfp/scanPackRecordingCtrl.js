groovepacks_admin_controllers.
    controller('scanPackRecordingCtrl', [ '$scope', '$http', '$timeout', '$stateParams', '$location', '$state', '$cookies','orders','scanPack',
        function( $scope, $http, $timeout, $stateParams, $location, $state, $cookies, orders, scanPack) {
            var myscope = {};
            var title;
            myscope.init = function() {
                $scope.rfpinit().then(function(){
                    console.log('stateParams: ');
                    console.log($stateParams);
                    console.log('state: ');
                    console.log($state.current.name);
                    console.log('scanPack');
                    console.log(scanPack);
                    if ($state.current.name == 'scanpack.rfp.no_match' || $state.current.name == 'scanpack.rfp.no_tracking_info' || $state.current.name == 'scanpack.rfp.verifying') {
                        title = "Scan Shipping Label for Order ";
                    }
                    else {
                        title = "Scan Tracking Number for Order ";
                    }
                    $scope.set('title',title+ $stateParams.order_num+"");
                    if($scope.data.order.status != 'awaiting' || $scope.data.order.unscanned_items.length > 0) {
                        $state.go('scanpack.rfp.default',{order_num:$stateParams.order_num});
                    }
                });

            }
            $scope.$on('reload-scanpack-state',myscope.init);
            myscope.init();
        }]);
