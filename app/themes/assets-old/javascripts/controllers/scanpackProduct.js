groovepacks_controllers.
    controller('scanPackProductCtrl', [ '$scope', '$http', '$timeout', '$stateParams', '$location', '$state', '$cookies','products','scanPack',
        function( $scope, $http, $timeout, $stateParams, $location, $state, $cookies, products, scanPack) {
            var myscope = {};

            myscope.init = function() {
                $scope.editinit().then(function() {
                    $timeout(function(){
                        if(typeof $scope.product_single_details == 'function') {
                            $scope.product_single_details($stateParams.id,false,null,true);
                        } else {
                            $scope.notify("Error loading product modal, please try again");
                            $state.go('scanpack.rfp.product_edit',{order_num: $stateParams.order_num});
                        }
                    });
                });
            }
            myscope.init();
        }]);
