groovepacks_controllers.
    controller('createStoreCtrl', [ '$scope', '$http', '$timeout', '$stateParams', '$location', '$state', '$cookies',
        function( $scope, $http, $timeout, $stateParams, $location, $state, $cookies) {
            var myscope = {};
            myscope.create_store = function() {
                $scope.setup_modal();
                $scope.$parent.edit_status = false;
                $scope.$parent.redirect = false;
                $scope.$parent.newStore = {};
                $scope.$parent.newStore.status = 1;
                $scope.$parent.ebay_show_signin_url = true;
                $scope.$parent.loading = false;


                for(var i=0; i<$scope.$parent.warehouses.list.length; 
                    i++) {
                    if ($scope.$parent.warehouses.list[i].info.is_default) {
                        $scope.$parent.newStore.inventory_warehouse_id =
                          $scope.$parent.warehouses.list[i].info.id;
                          console.log($scope.$parent.newStore);
                        break;
                    }
                }
                $http.get('/store_settings/getebaysigninurl.json').success(function(data) {
                    if (data.ebay_signin_url_status && typeof
                        $scope.$parent!='undefined' && 
                        $scope.$parent != null)
                    {
                        $scope.$parent.ebay_signin_url = data.ebay_signin_url;
                        $scope.$parent.ebay_signin_url_status = data.ebay_signin_url_status;
                        $scope.$parent.ebay_sessionid = data.ebay_sessionid;
                    }

                }).error(function(data) {
                        $scope.$parent.ebay_signin_url_status = false;

                    });

                $scope.store_modal.modal('show');
            }

            myscope.init = function() {
                $scope.init().then(function() {
                    $scope.$parent.redirect = ($stateParams.redirect || ($stateParams.action == "create"));
                    if ($scope.$parent.redirect)
                    {
                        
                        if ($stateParams.editstatus=='true')
                        {
                            $scope.$parent.edit_status = $stateParams.editstatus;
                            $scope.retrieveandupdateusertoken($stateParams.storeid);
                            $scope.$parent.newStore = new Object();
                            $scope.$parent.newStore.id = $stateParams.storeid;

                            $scope.$parent.newStore.name = $stateParams.name;
                
                            $scope.$parent.newStore.status = ($stateParams.status ==true);
                            $scope.$parent.newStore.store_type = $stateParams.storetype;

                            $scope.$parent.newStore.inventory_warehouse_id = parseInt($stateParams.inventorywarehouseid);
                            $scope.$parent.newStore.import_images = ($stateParams.importimages == 'true');
                            $scope.$parent.newStore.import_products = ($stateParams.importproducts == 'true');
                            $scope.$parent.newStore.thank_you_message_to_customer = $stateParams.messagetocustomer;

                        }
                        else
                        {
                            $scope.ebayuserfetchtoken();
                            $scope.$parent.newStore = {};
                            $scope.$parent.newStore.name = $stateParams.name;
                            $scope.$parent.newStore.status = ($stateParams.status ==true);
                            $scope.$parent.newStore.store_type = $stateParams.storetype;
                            
                            $scope.$parent.newStore.inventory_warehouse_id = parseInt($stateParams.inventorywarehouseid);
                            $scope.$parent.newStore.import_images = ($stateParams.importimages == 'true');
                            $scope.$parent.newStore.import_products = ($stateParams.importproducts == 'true');
                            $scope.$parent.newStore.thank_you_message_to_customer = $stateParams.messagetocustomer;
                            
                        }
                        if(typeof $scope.$parent.newStore.status == "undefined") {
                            $scope.$parent.newStore.status = 1;                           
                        }
                    
                        $scope.setup_modal();
                        $scope.store_modal.modal('show');
                    }
                    else
                    {
                        $timeout(myscope.create_store);
                    }

                })

            }

            myscope.init();
        }]);
