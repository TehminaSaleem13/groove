groovepacks_controllers.
controller('showStoresCtrl', [ '$scope', '$http', '$timeout', '$routeParams', '$location', '$route', '$cookies',
    function( $scope, $http, $timeout, $routeParams, $location, $route, $q, $cookies) {

        $scope.current_page="show_stores";


    	$http.get('/home/userinfo.json').success(function(data){
    		$scope.username = data.username;
    	});

    	$http.get('/store_settings/storeslist.json').success(function(data) {
    		$scope.stores = data;
    		$scope.reverse = false;
            $scope.newUser = {};
    	}).error(function(data) {
    		$scope.error_msg = "There was a problem retrieving stores list";
    		$scope.show_error = true;
    	});

        $scope.orderimport_type = 'apiimport';
        $scope.productimport_type = 'apiimport';


    	$scope.submit = function() {

    		$http.post('/store_settings/createStore.json', $scope.newStore).success(function(data) {
    			if(!data.status)
    			{
    				$scope.error_msgs = data.messages;
    				$scope.show_error_msgs = true;
    			}
    			else
    			{
    				$scope.show_error_msgs = false;
    				$scope.newStore = {};
    				$('#createStore').modal('hide');

    				$http.get('/store_settings/storeslist.json').success(function(data) {
						    		var storesScope = angular.element($("#storestbl")).scope();
								      storesScope.stores = data;
								      if(!$scope.$$phase) {
								        storesScope.$apply();
								      }
						    	}).error(function(data) {
						    		$scope.error_msg = "There was a problem retrieving stores list.";
						    		$scope.show_error = true;
						    	});
                    $scope.edit_status = false;
    			}
    		})
    	}

    	$scope.handlesort = function(predicate) {
    		$scope.predicate = predicate;
    		if ($scope.reverse == false)
    		{
    			$scope.reverse = true;
    		}
    		else
    		{
    			$scope.reverse = false;
    		}

    	}

        $scope.handle_change_status = function(event) {

            storeArray = [];

            /* get user objects of checked items */
            for( var store_index=0; store_index<= $scope.stores.length-1; store_index++)
            {
                if ($scope.stores[store_index].checked == 1)
                {
                    var store = new Object();
                    store.id = $scope.stores[store_index].id;
                    store.index = store_index;
                    if(event=='active')
                    {
                        store.status = 1;
                    }
                    else
                    {
                        store.status = 0;
                    }
                    storeArray.push(store);
                }
            }
            /* update the server with the changed status */
            $http.put('/store_settings/changestorestatus.json', storeArray).success(function(data){
                if (data.status)
                {
                    for(i=0; i<= storeArray.length -1; i++)
                    {
                        $scope.stores[storeArray[i].index].status = storeArray[i].status;
                        $scope.stores[storeArray[i].index].checked = false;
                    }

                    $scope.select_deselectall = false;                         
                }
                else
                {
                    $scope.error_msg = "There was a problem changing stores status";
                    $scope.show_error = true;
                }
                }).error(function(data){
                            $scope.error_msg = "There was a problem changing stores status";
                            $scope.show_error = true;
                    });
        }

        $scope.handle_store_delete_event = function(event) {

            storeArray = [];
            /* get user objects of checked items */
            for( var store_index=0; store_index<= $scope.stores.length-1; store_index++)
            {
                if ($scope.stores[store_index].checked == 1)
                {
                    var store = new Object();
                    store.id = $scope.stores[store_index].id;
                    store.index = store_index;
                    storeArray.push(store);
                }
            }
            console.log(storeArray);
            /* update the server with the changed status */
            $http.put('/store_settings/deletestore.json', storeArray).success(function(data){
                        if (data.status)
                        { 
                            $http.get('/store_settings/storeslist.json').success(function(data) {
                                $scope.stores = data;
                                $scope.reverse = false;
                            }).error(function(data) {
                                $scope.error_msg = "There was a problem retrieving stores list";
                                $scope.show_error = true;
                            });                         
                        }
                        else
                        {
                            $scope.error_msg = "There was a problem deleting stores";
                            $scope.show_error = true;
                        }
                        }).error(function(data){
                            $scope.error_msg = "There was a problem changing stores status";
                            $scope.show_error = true;
                        });
        }

        $scope.handle_store_duplicate_event = function(event) {

            storeArray = [];
            /* get user objects of checked items */
            for( var store_index=0; store_index<= $scope.stores.length-1; store_index++)
            {
                if ($scope.stores[store_index].checked)
                {
                    var store = new Object();
                    store.id = $scope.stores[store_index].id;
                    store.index = store_index;
                    storeArray.push(store);
                }
            }
            /* update the server with the changed status */
            $http.put('/store_settings/duplicatestore.json', storeArray).success(function(data){
                        if (data.status)
                        { 
                            $http.get('/store_settings/storeslist.json').success(function(data) {
                                $scope.stores = data;
                                $scope.reverse = false;
                            }).error(function(data) {
                                $scope.error_msg = "There was a problem retrieving stores list";
                                $scope.show_error = true;
                            });                         
                        }
                        else
                        {
                            $scope.error_msg = "There was a problem duplicating stores";
                            $scope.show_error = true;
                        }
                        }).error(function(data){
                            $scope.error_msg = "There was a problem duplicating stores";
                            $scope.show_error = true;
                        });
        }

    $scope.getstoreinfo = function(id) {
            /* update the server with the changed status */
            $http.get('/store_settings/getstoreinfo.json?id='+id).success(function(data){
                        if (data.status)
                        { 
                            $scope.newStore = data.store;
                            $scope.edit_status = true;
                            if (data.store.store_type == 'Magento')
                            {
                                $scope.newStore.host = data.credentials.magento_credentials.host;
                                $scope.newStore.username = data.credentials.magento_credentials.username;  
                                $scope.newStore.password = data.credentials.magento_credentials.password;
                                $scope.newStore.api_key = data.credentials.magento_credentials.api_key;

                                $scope.newStore.producthost = data.credentials.magento_credentials.producthost;
                                $scope.newStore.productusername = data.credentials.magento_credentials.productusername;  
                                $scope.newStore.productpassword = data.credentials.magento_credentials.productpassword;
                                $scope.newStore.productapi_key = data.credentials.magento_credentials.productapi_key;
                                $scope.newStore.import_products = data.credentials.magento_credentials.import_products; 
                                $scope.newStore.import_images = data.credentials.magento_credentials.import_images;              

                            }
                            if (data.store.store_type == 'Ebay')
                            {
                                $scope.newStore.ebay_app_id = data.credentials.ebay_credentials.app_id;
                                $scope.newStore.ebay_auth_token = data.credentials.ebay_credentials.auth_token;  
                                $scope.newStore.ebay_cert_id = data.credentials.ebay_credentials.cert_id;
                                $scope.newStore.ebay_dev_id = data.credentials.ebay_credentials.dev_id; 

                                $scope.newStore.productebay_app_id = data.credentials.ebay_credentials.productapp_id;
                                $scope.newStore.productebay_auth_token = data.credentials.ebay_credentials.productauth_token;  
                                $scope.newStore.productebay_cert_id = data.credentials.ebay_credentials.productcert_id;
                                $scope.newStore.productebay_dev_id = data.credentials.ebay_credentials.productdev_id;
                                $scope.newStore.import_products = data.credentials.ebay_credentials.import_products; 
                                $scope.newStore.import_images = data.credentials.ebay_credentials.import_images;         
                            }
                            if (data.store.store_type == 'Amazon')
                            {
                                $scope.newStore.access_key_id = data.credentials.amazon_credentials.access_key_id;
                                $scope.newStore.app_name = data.credentials.amazon_credentials.app_name;  
                                $scope.newStore.app_version = data.credentials.amazon_credentials.app_version;
                                $scope.newStore.marketplace_id = data.credentials.amazon_credentials.marketplace_id; 
                                $scope.newStore.merchant_id = data.credentials.amazon_credentials.merchant_id;
                                $scope.newStore.secret_access_key = data.credentials.amazon_credentials.secret_access_key;

                                $scope.newStore.productaccess_key_id = data.credentials.amazon_credentials.productaccess_key_id;
                                $scope.newStore.productapp_name = data.credentials.amazon_credentials.productapp_name;  
                                $scope.newStore.productapp_version = data.credentials.amazon_credentials.productapp_version;
                                $scope.newStore.productmarketplace_id = data.credentials.amazon_credentials.productmarketplace_id; 
                                $scope.newStore.productmerchant_id = data.credentials.amazon_credentials.productmerchant_id;
                                $scope.newStore.productsecret_access_key = data.credentials.amazon_credentials.productsecret_access_key;        
                                $scope.newStore.import_products = data.credentials.amazon_credentials.import_products; 
                                $scope.newStore.import_images = data.credentials.amazon_credentials.import_images;   
                            }
                            $('#createStore').modal('show');                
                        }
                        else
                        {
                            $scope.error_msg = "There was a problem getting store information";
                            $scope.show_error = true;
                        }
                        }).error(function(data){
                            $scope.error_msg = "There was a problem getting store information";
                            $scope.show_error = true;
                        });
    }

    $scope.select_deselectall_event = function() {
        /* get user objects of checked items */
        //alert("checked");
        for( var store_index=0; store_index<= $scope.stores.length-1; store_index++)
        {
            $scope.stores[store_index].checked = $scope.select_deselectall;
        }
    }

    $scope.create_store = function() {
        $scope.edit_status = false;
        $scope.newStore = {};
        $('#createStore').modal('show'); 
    }

    $scope.copydata =function(event) {

        if (event){

            if ($scope.newStore.store_type == 'Magento')
                {
                    $scope.newStore.producthost = $scope.newStore.host;
                    $scope.newStore.productusername = $scope.newStore.username;  
                    $scope.newStore.productpassword = $scope.newStore.password;
                    $scope.newStore.productapi_key = $scope.newStore.api_key;       
                }
                if ($scope.newStore.store_type == 'Ebay')
                {
                    $scope.newStore.productebay_app_id = $scope.newStore.ebay_app_id;
                    $scope.newStore.productebay_auth_token = $scope.newStore.ebay_auth_token;  
                    $scope.newStore.productebay_cert_id = $scope.newStore.ebay_cert_id;
                    $scope.newStore.productebay_dev_id = $scope.newStore.ebay_dev_id;       
                }
                if ($scope.newStore.store_type == 'Amazon')
                {
                    $scope.newStore.productaccess_key_id = $scope.newStore.access_key_id;
                    $scope.newStore.productapp_name = $scope.newStore.app_name;  
                    $scope.newStore.productapp_version = $scope.newStore.app_version;
                    $scope.newStore.productmarketplace_id = $scope.newStore.marketplace_id; 
                    $scope.newStore.productmerchant_id = $scope.newStore.merchant_id;
                    $scope.newStore.productsecret_access_key = $scope.newStore.secret_access_key;        
                }
        }
        else
        {
                if ($scope.newStore.store_type == 'Magento')
                {
                    $scope.newStore.producthost = "";
                    $scope.newStore.productusername = "";  
                    $scope.newStore.productpassword = "";
                    $scope.newStore.productapi_key = "";       
                }
                if ($scope.newStore.store_type == 'Ebay')
                {
                    $scope.newStore.productebay_app_id = "";
                    $scope.newStore.productebay_auth_token = "";  
                    $scope.newStore.productebay_cert_id = "";
                    $scope.newStore.productebay_dev_id = "";       
                }
                if ($scope.newStore.store_type == 'Amazon')
                {
                    $scope.newStore.productaccess_key_id = "";
                    $scope.newStore.productapp_name = "";  
                    $scope.newStore.productapp_version = "";
                    $scope.newStore.productmarketplace_id = ""; 
                    $scope.newStore.productmerchant_id = "";
                    $scope.newStore.productsecret_access_key = "";        
                }
        }
    }

    }]);