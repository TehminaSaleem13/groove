groovepacks_controllers.
    controller('showScanPackCtrl', [ '$scope', '$http', '$timeout', '$stateParams', '$location', '$state', '$cookies','scanPack','orders',
        function( $scope, $http, $timeout, $stateParams, $location, $state, $cookies, scanPack, orders) {
            var myscope = {};
            $scope.init = function() {
                myscope.callbacks = {};
                $scope.current_state = $state.current.name;
                if(typeof $scope.data == "undefined") {
                    $scope.data = {};
                }
                $scope.data.input = "";
                console.log($scope.current_state);
            }

            $scope.set = function(key, val) {
                $scope.data[key] = val;
            }

            $scope.input_enter = function(event) {
                if(event.which != '13') return;
                var id = null;
                if(typeof $scope.data.order.id !== "undefined") {
                    id = $scope.data.order.id;
                }
                scanPack.input($scope.data.input,$scope.current_state,id).then(
                    function(data) {
                        $scope.set('raw',data.data);
                        if(typeof data.data.data != "undefined") {
                            if(typeof data.data.data.order != "undefined") {
                                $scope.set('order',data.data.data.order);
                            }
                            if(typeof data.data.data.next_state != "undefined") {
                                if($state.current.name == data.data.data.next_state) {
                                    $scope.$broadcast('reload-scanpack-state');
                                } else {
                                    $state.go(data.data.data.next_state,data.data.data);
                                }
                            }
                        }
                    }
                );
            }
}]);
