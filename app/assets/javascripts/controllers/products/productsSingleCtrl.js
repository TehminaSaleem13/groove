groovepacks_controllers.
    controller('productsSingleCtrl', [ '$scope', '$http', '$timeout', '$stateParams', '$location', '$state', '$cookies','products','$modal','$modalStack','$previousState',
        function( $scope, $http, $timeout, $stateParams, $location, $state, $cookies,products,$modal,$modalStack,$previousState) {
            //Definitions

            var myscope = {};
            /*
             * Public methods
             */


            myscope.init = function() {
                if(typeof $scope.product_next !='function') {
                    $scope.product_next = function(func) {
                        if (typeof func == "function") {
                            func();
                        }
                    };
                }
                if(typeof $scope.select_all_toggle !='function') {
                    $scope.select_all_toggle = function() {};
                }
                if(!$previousState.get("product-modal-previous") || $modalStack.getTop() == null) {
                    //Show modal here
                    myscope.prod_obj= $modal.open({
                        templateUrl: '/assets/views/modals/product/main.html',
                        controller: 'productsSingleModal',
                        size:'lg',
                        resolve: {
                            product_data: function(){return $scope.products},
                            product_next: function(){return $scope.product_next},
                            product_id: function(){return false;}
                        }
                    });
                    $previousState.forget("product-modal-previous");
                    $previousState.memo("product-modal-previous");
                    myscope.prod_obj.result.finally(function(){
                        $scope.select_all_toggle(false);
                        $scope.$emit("product-modal-closed");
                        if($previousState.get("product-modal-previous").state.name == "" ||
                            $previousState.get("product-modal-previous").state.name.indexOf('single', $previousState.get("product-modal-previous").state.name.length - 6) !== -1) {
                            //If you landed directly on this URL, we assume that the last part of the state is the modal
                            //So we remove that and send user on their way.
                            // If there is no . in the string, we send user to home
                            var toState = "home";
                            var pos = $state.current.name.lastIndexOf(".");
                            if (pos!=-1) {
                                toState = $state.current.name.slice(0,pos);
                            }
                            $previousState.forget("product-modal-previous");
                            $timeout(function(){$state.go(toState,$stateParams);},700);
                        } else {
                            $timeout(function(){$previousState.go("product-modal-previous");$previousState.forget("product-modal-previous");},700);

                        }
                    });
                }

            };

            myscope.init();

        }]);
