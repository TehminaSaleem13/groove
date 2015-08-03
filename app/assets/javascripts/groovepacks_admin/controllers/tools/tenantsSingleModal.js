groovepacks_admin_controllers.
    controller('tenantsSingleModal', [ '$scope', '$http', '$timeout', '$stateParams', '$location', '$state', '$cookies','$modal','$modalInstance','tenant_data','tenant_id','tenants',
        function( $scope, $http, $timeout, $stateParams, $location, $state, $cookies,$modal,$modalInstance,tenant_data,tenant_id,tenants) {
            //Definitions

            var myscope = {};
            /*
             * Public methods
             */

            $scope.ok = function() {
                $modalInstance.close("ok-button-click");
            };
            
            $scope.cancel = function () {
                $modalInstance.dismiss("cancel-button-click");
            };

            $scope.update_access_restrictions = function() {
                console.log("in update_access_restricions");
                console.log($scope.tenants);
                tenants.single.update($scope.tenants);
            }

            myscope.tenant_single_details = function(id) {
                //console.log(index);
                //console.log(scope.tenants);

                for(var i = 0; i< $scope.tenants.list.length; i++) {
                    if($scope.tenants.list[i].id == id) {
                        $scope.tenants.current = parseInt(i);
                        break;
                    }
                }

                tenants.single.get(id,$scope.tenants).success(function(data) {
                    console.log("tenant_data");
                    console.log(tenant_data);
                });
            };

            myscope.init = function() {
                
                $scope.tenants = tenant_data;
                console.log("tenant_id");
                console.log(tenant_id);
                if (tenant_id) {
                    myscope.tenant_single_details(tenant_id);
                } else {
                    myscope.tenant_single_details($stateParams.tenant_id);
                };
                
            };

            myscope.init();

        }]);
