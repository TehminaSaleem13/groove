groovepacks_controllers.
    controller('scanPackRfpCtrl', [ '$scope', '$http', '$timeout', '$stateParams', '$location', '$state', '$cookies','$q','scanPack',
        function( $scope, $http, $timeout, $stateParams, $location, $state, $cookies, $q, scanPack) {
            /**
             * Checks if call is on direct url and returns promise to support .then in both cases
             */
            $scope.rfpinit = function() {
                $scope.init();
                var result = $q.defer();
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

                        }
                    }).then(result.resolve);
                }
                return result.promise;
            }
}]);
