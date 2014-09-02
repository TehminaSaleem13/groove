groovepacks_controllers.
    controller('ordersSingleCtrl', [ '$scope', '$http', '$timeout', '$stateParams', '$location', '$state', '$cookies','orders','$modal','$modalStack','$previousState',
        function( $scope, $http, $timeout, $stateParams, $location, $state, $cookies,orders,$modal,$modalStack,$previousState) {
            //Definitions

            var myscope = {};
            /*
             * Public methods
             */


            myscope.init = function() {
                if(!$previousState.get("order-modal-previous") || $modalStack.getTop() == null) {
                    //Show modal here
                    myscope.order_obj= $modal.open({
                        templateUrl: '/assets/views/modals/order/main.html',
                        controller: 'ordersSingleModal',
                        size:'lg',
                        resolve: {
                            order_data: function(){return $scope.orders},
                            load_page: function(){return $scope.load_page}
                        }
                    });
                    $previousState.forget("order-modal-previous");
                    $previousState.memo("order-modal-previous");
                    myscope.order_obj.result.finally(function(){
                        $scope.select_all_toggle(false);
                        $scope.$emit("order-modal-closed");
                        if($previousState.get("order-modal-previous").state.name == "" ||
                            $previousState.get("order-modal-previous").state.name.indexOf('single', $previousState.get("order-modal-previous").state.name.length - 6) !== -1) {
                            //If you landed directly on this URL, we assume that the last part of the state is the modal
                            //So we remove that and send user on their way.
                            // If there is no . in the string, we send user to home
                            var toState = "home";
                            var pos = $state.current.name.lastIndexOf(".");
                            if (pos!=-1) {
                                toState = $state.current.name.slice(0,pos);
                            }
                            $previousState.forget("order-modal-previous");
                            $timeout(function(){$state.go(toState,$stateParams);},700);
                        } else {
                            $timeout(function(){$previousState.go("order-modal-previous");$previousState.forget("order-modal-previous");},700);

                        }
                    });
                }

            };

            myscope.init();

        }]);
