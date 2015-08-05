groovepacks_admin_controllers.
    controller('tenantsSingleCtrl', [ '$scope', '$http', '$timeout', '$stateParams', '$location', '$state', '$cookies','$modal','$modalStack','$previousState',
        function( $scope, $http, $timeout, $stateParams, $location, $state, $cookies,$modal,$modalStack,$previousState) {
            //Definitions

            var myscope = {};
            /*
             * Public methods
             */


            myscope.init = function() {
                if(!$previousState.get("tenant-modal-previous") || $modalStack.getTop() == null) {
                    //Show modal here
                    myscope.tenant_obj= $modal.open({
                        templateUrl: '/assets/admin_views/modals/tenants/main.html',
                        controller: 'tenantsSingleModal',
                        size:'lg',
                        resolve: {
                            tenant_data: function(){return $scope.tenants},
                            load_page: function(){return $scope.load_page},
                            tenant_id: function(){return false;}
                        }
                    });
                    $previousState.forget("tenant-modal-previous");
                    $previousState.memo("tenant-modal-previous");
                    myscope.tenant_obj.result.finally(function(){
                        $scope.select_all_toggle(false);
                        $scope.tenant_modal_closed_callback();
                        if($previousState.get("tenant-modal-previous").state.name == "" ||
                            $previousState.get("tenant-modal-previous").state.name.indexOf('single', $previousState.get("tenant-modal-previous").state.name.length - 6) !== -1) {
                            //If you landed directly on this URL, we assume that the last part of the state is the modal
                            //So we remove that and send user on their way.
                            // If there is no . in the string, we send user to home
                            var toState = "home";
                            var pos = $state.current.name.lastIndexOf(".");
                            if (pos!=-1) {
                                toState = $state.current.name.slice(0,pos);
                            }
                            $previousState.forget("tenant-modal-previous");
                            $timeout(function(){$state.go(toState,$stateParams);},700);
                        } else {
                            $timeout(function(){$previousState.go("tenant-modal-previous");$previousState.forget("tenant-modal-previous");},700);

                        }
                    });
                }
            };

            myscope.init();

        }]);
