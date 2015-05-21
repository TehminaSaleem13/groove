groovepacks_admin_controllers.
    controller('scanPackRfpCtrl', [ '$scope', '$http', '$timeout', '$stateParams', '$location', '$state', '$cookies','$q','scanPack',
        function( $scope, $http, $timeout, $stateParams, $location, $state, $cookies, $q, scanPack) {
            /**
             * Checks if call is on direct url and returns promise to support .then in both cases
             */
            $scope.rfpinit = function() {
                $scope.alternate_orders = [];
                $scope.init();
                var result = $q.defer();
                result.promise.then(function() {
                    if(typeof $scope.data.raw.data != "undefined"
                           && typeof $scope.data.raw.data.matched_orders != "undefined"
                        &&  $scope.data.raw.data.matched_orders.length > 0) {
                        var index = $scope.data.raw.data.matched_orders.indexOf($scope.data.order.increment_id);
                        if(index!= -1) {
                            $scope.data.raw.data.matched_orders.splice(index,1);
                        }
                        $scope.alternate_orders = $scope.data.raw.data.matched_orders;

                    }
                });
                if(typeof $scope.data.order != 'undefined' && typeof $scope.data.order.status != 'undefined') {
                    result.resolve();
                } else {
                    return scanPack.input($stateParams.order_num,'scanpack.rfo',null).then(function(data) {
                        $scope.set('raw',data.data);
                        if(typeof data.data != 'undefined' && typeof data.data.data != 'undefined') {
                            if(typeof data.data.data['next_state'] != 'undefined' &&  data.data.data['next_state'] != $state.current.name) {
                                $state.go(data.data.data['next_state'],{order_num: $stateParams.order_num});
                            }
                            $scope.set('order', data.data.data.order);
                            $scope.set('scan_pack_settings', data.data.data.scan_pack_settings);
                        }
                    }).then(result.resolve);
                }
                return result.promise;
            }
}]);
