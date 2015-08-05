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

            $scope.update = function(reason) {
                if(reason == "cancel-button-click" || reason == "ok-button-click") {
                    myscope.rollback();
                }
            };

            $scope.update_access_restrictions = function() {
                tenants.single.update($scope.tenants).then(function() {
                    myscope.init();
                });
            };

            $scope.delete_orders = function() {
                $scope.delete('orders');
            };

            $scope.delete_products = function() {
                $scope.delete('products');
            };

            $scope.delete_orders_and_products = function() {
                $scope.delete('both');
            };

            $scope.delete_all = function() {
                $scope.delete('all');
            };

            $scope.delete = function(type) {
                myscope.tenant_obj= $modal.open({
                    templateUrl: '/assets/admin_views/modals/tenants/delete.html',
                    controller: 'tenantsDeleteModal',
                    size:'md',
                    resolve: {
                        tenant_data: function(){return $scope.tenants},
                        load_page: function(){return $scope.load_page},
                        deletion_type: function(){return type;}
                    }
                });
                myscope.tenant_obj.result.finally(function(){
                    myscope.init();
                });
            };

            myscope.rollback = function() {
                $state.go("tools.type.page",$stateParams);
            };

            myscope.tenant_single_details = function(id) {

                for(var i = 0; i< $scope.tenants.list.length; i++) {
                    if($scope.tenants.list[i].id == id) {
                        $scope.tenants.current = parseInt(i);
                        break;
                    }
                }

                tenants.single.get(id,$scope.tenants).success(function(data) {});
            };

            myscope.init = function() {
                
                $scope.tenants = tenant_data;
                if (tenant_id) {
                    myscope.tenant_single_details(tenant_id);
                } else {
                    myscope.tenant_single_details($stateParams.tenant_id);
                };
                $modalInstance.result.then($scope.update,$scope.update);
            };

            myscope.init();

        }]);
