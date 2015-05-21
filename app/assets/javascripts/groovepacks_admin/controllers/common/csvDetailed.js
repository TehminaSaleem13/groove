groovepacks_admin_controllers.
    controller('csvDetailed', [ '$scope', '$http', '$timeout', '$stateParams', '$location', '$state', '$modal',
        '$modalStack','$previousState', 'stores',
        function( $scope, $http, $timeout, $stateParams, $location, $state,$modal,$modalStack,$previousState, stores) {
            var myscope = {};

            myscope.update_single_store = function() {
                stores.single.update($scope.stores,false).success(function(data){
                    if(data.status && data.store_id) {
                        //Use FileReader API here if it exists (post prototype feature)
                        if (data.csv_import && data.store_id) {
                            var csv_modal = $modal.open({
                                templateUrl: '/assets/views/modals/settings/stores/csv_import_detailed.html',
                                controller: 'csvDetailedModal',
                                size:'lg',
                                resolve: {
                                    store_data: function(){return $scope.stores;}
                                }
                            });
                            csv_modal.result.finally(function() {
                                $state.transitionTo($state.current, $stateParams, {
                                    reload: true,
                                    inherit: false,
                                    notify: true
                                });
                            });
                        }
                    }
                });
            };

            myscope.init = function() {
                $scope.stores = stores.model.get();
                stores.single.get_system($scope.stores);
                $scope.$on("fileSelected", function (event, args) {
                    if(args.name == 'productfile') {
                        $scope.$apply(function () {
                            $scope.stores.single[args.name] = args.file;
                            $scope.stores.single.type = 'product';
                            myscope.update_single_store();
                        });
                    }
                });

            };
            myscope.init();
        }]);
