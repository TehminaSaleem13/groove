groovepacks_admin_controllers.
    controller('productsSingleCtrl', [ '$scope', '$http', '$timeout', '$stateParams', '$location', '$state', '$cookies','products','$modal','$modalStack','$previousState','$q',
        function( $scope, $http, $timeout, $stateParams, $location, $state, $cookies,products,$modal,$modalStack,$previousState,$q) {
            //Definitions

            var myscope = {};
            /*
             * Public methods
             */


            myscope.init = function() {
                if(typeof $scope.load_page !='function') {
                    $scope.load_page = function() {
                        var req = $q.defer();
                        req.reject();
                        return req.promise;
                    };
                }
                if(typeof $scope.select_all_toggle !='function') {
                    $scope.select_all_toggle = function() {};
                }
                if(typeof $scope.product_modal_closed_callback !='function') {
                    $scope.product_modal_closed_callback = function() {};
                }
                if(!$previousState.get("product-modal-previous") || $modalStack.getTop() == null) {
                    //Show modal here
                    myscope.prod_obj= $modal.open({
                        templateUrl: '/assets/views/modals/product/main.html',
                        controller: 'productsSingleModal',
                        size:'lg',
                        resolve: {
                            product_data: function(){return $scope.products},
                            load_page: function(){return $scope.load_page},
                            product_id: function(){return false;}
                        }
                    });
                    $previousState.forget("product-modal-previous");
                    $previousState.memo("product-modal-previous");
                    myscope.prod_obj.result.finally(function(){
                        $scope.select_all_toggle(false);
                        $scope.product_modal_closed_callback();
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
