groovepacks_admin_controllers.
    controller('storeSingleCtrl', [ '$scope', '$http', '$timeout', '$stateParams', '$location', '$state', '$modal',
                                    '$modalStack','$previousState', '$cookies',
        function( $scope, $http, $timeout, $stateParams, $location, $state,$modal,$modalStack,$previousState, $cookies) {
            var myscope = {};

            myscope.init = function() {
                if(!$previousState.get("store-modal-previous") || $modalStack.getTop() == null) {
                    //Show modal here
                    myscope.store_obj= $modal.open({
                        templateUrl: '/assets/views/modals/settings/stores/main.html',
                        controller: 'storeSingleModal',
                        size:'lg',
                        resolve: {
                            store_data: function(){return $scope.stores}
                        }
                    });
                    $previousState.forget("store-modal-previous");
                    $previousState.memo("store-modal-previous");
                    myscope.store_obj.result.finally(function(){
                        $scope.select_all_toggle(false);
                        $scope.store_modal_closed_callback();
                        if($previousState.get("store-modal-previous").state.name == "" ||
                           $previousState.get("store-modal-previous").state.name.indexOf(
                               'single', $previousState.get("store-modal-previous").state.name.length - 6) !== -1) {
                            //If you landed directly on this URL, we assume that the last part of the state is the modal
                            //So we remove that and send user on their way.
                            // If there is no . in the string, we send user to home
                            var toState = "home";
                            var pos = $state.current.name.lastIndexOf(".");
                            if (pos!=-1) {
                                toState = $state.current.name.slice(0,pos);
                            }
                            $previousState.forget("store-modal-previous");
                            $timeout(function(){$state.go(toState,$stateParams);},700);
                        } else {
                            $timeout(function(){
                                $previousState.go("store-modal-previous");
                                $previousState.forget("store-modal-previous");
                            },700);
                        }
                    });
                }

            };

            myscope.init();
        }]);
