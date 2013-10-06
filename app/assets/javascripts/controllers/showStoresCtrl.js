groovepacks_controllers.
controller('showStoresCtrl', [ '$scope', '$http', '$timeout', '$routeParams', '$location', '$route', '$cookies',
    function( $scope, $http, $timeout, $routeParams, $location, $route, $q, $cookies) {

        $scope.current_page="show_stores";
        $scope.$on("fileSelected", function (event, args) {
            $scope.$apply(function () {
                $scope.newStore[args.name] = args.file;
            });
            $("input[type='file']").val('');
        });

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


    	$scope.submit = function() {

            $http({
                method: 'POST',
                headers: { 'Content-Type': false },
                url:'/store_settings/createStore.json',
                transformRequest: function (data) {
                    var request = new FormData();
                    for (var key in data) {
                        request.append(key,data[key]);
                    }
                    return request;
                },
                 data: $scope.newStore
            }).success(function(data) {
                if(!data.status)
    			{
    				$scope.error_msgs = data.messages;
    				$scope.show_error_msgs = true;
    			}
    			else
    			{
    				$scope.show_error_msgs = false;
                    $scope.error_msgs = {};
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

                    //Use FileReader API here if it exists (post prototype feature)
                    if(data.csv_import && data.store_id) {
                        $http.get('/store_settings/csvImportData.json?id='+data.store_id).success(function(data) {
                            $scope.csv_init(data);
                            $('#importCsv').modal('show');

                        }).error(function(data) {
                            $scope.error_msg = "There was a problem retrieving stores list.";
                            $scope.show_error = true;
                        })
                    }
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


    $scope.import_products = function() {
            $scope.importproduct_status = "Import in progress";
            $scope.importproductstatus_show = true;
            $http.get('/products/importproducts/'+$scope.newStore.id+'.json').success(function(data){
                console.log(data);
                if (data.status)
                {
                $scope.importproduct_status="Successfully imported "+data.success_imported+" of "+data.total_imported+" products";
                }
                else
                {
                $scope.importproduct_status = "Import failed."
                }
            //$scope.importproduct_status = "Import completed";
            }).error(function(data) {

            });      
    }
    $scope.csv_init = function(data) {
        $scope.csvimporter = {};
        $scope.csvimporter.default_map = {value:'none', name:"Unmapped"};
        if("product" in data && "data" in data["product"]) {
            $scope.csvimporter.product = data["product"];
            $scope.csvimporter.type = "product";
        }
        if("order" in data && "data" in data["order"]) {
            $scope.csvimporter.order = data["order"];
            $scope.csvimporter.type = "order";
        }
        $scope.current = $scope.csvimporter[$scope.csvimporter.type]["settings"];
        $scope.current.store_id = data["store_id"];
        $scope.current.type = $scope.csvimporter.type;
        $scope.parse();
        for(i in $scope.current.map) {
          $(".csv-preview-" + $scope.current.map[i].value).addClass("disabled");
        }
    }

    $scope.import_csv = function() {
        $http.post('store_settings/csvDoImport.json',$scope.current).success(function(data){
            if(!data.status) {
                $scope.error_msgs = data.messages;
                $scope.show_error_msgs = true;
                $scope.current.rows = $scope.current.rows + data.last_row
            } else {
                $scope.show_error_msgs = false;
                $scope.error_msgs = {};
                $scope.current = {};
                $scope.csvimporter = {};
                $('#importCsv').modal('hide');
            }
        });

    }
    $scope.parse = function() {
        //Show loading sign
        //This needs WebWorkers to work for real, apply in post-prototype version
        $("#csv_parsing").show();
        $scope.current.data = [];
        $scope.empty_cols = [];
        in_entry = false;
        secondary_split = [];
        initial_split = $scope.csvimporter[$scope.csvimporter.type]["data"].split(/\r?\n/g);
        tmp_record = '';
        row_array = [];
        separator = $scope.current.sep;
        if(separator == '') {
            separator = " ";
        }
        final_record = [];
        maxcolumns = 0;
        for( i in initial_split) {
            if($scope.current.fix_width == 1) {
                row_array = initial_split[i].chunk($scope.current.fixed_width);
                if(maxcolumns < row_array.length) {
                    maxcolumns = row_array.length;
                }
                final_record.push(row_array);
                row_array = [];
            } else {
                secondary_split = initial_split[i].split(separator);
                for(j in secondary_split) {
                    if(secondary_split[j].charAt(0) == $scope.current.delimiter && secondary_split[j].charAt(secondary_split[j].length -1) != $scope.current.delimiter) {
                        in_entry = true;
                    } else if(secondary_split[j].charAt(secondary_split[j].length -1) == $scope.current.delimiter) {
                        in_entry = false;
                    }

                    if(in_entry) {
                        if( j == secondary_split.length -1) {
                            tmp_record += secondary_split[j];
                        } else {
                            tmp_record += secondary_split[j]+separator;
                        }
                    } else {
                        row_array.push((tmp_record + secondary_split[j]).trimmer($scope.current.delimiter));
                        if( j == secondary_split.length -1) {
                            tmp_record = "";
                        } else {
                            tmp_record = $scope.current.delimiter;
                        }
                    }
                }
                if(in_entry) {
                    tmp_record += "\r\n";

                } else {
                    if(maxcolumns < row_array.length) {
                        maxcolumns = row_array.length;
                    }
                    final_record.push(row_array);
                    row_array = [];
                }
            }
        }
        for(i = 0; i< maxcolumns; i++) {
            $scope.empty_cols.push(i);
            if((i in $scope.current.map && 'name' in $scope.current.map[i] && 'value' in $scope.current.map[i]) ) {
                //$scope.column_map(i,$scope.current.map[i]);
                $(".csv-preview-" + $scope.current.map[i].value).addClass("disabled");
            } else {
                $scope.current.map[i] = $scope.csvimporter.default_map;
            }
        }
        $scope.current.data = final_record.slice($scope.current.rows-1);
        $scope.current.data.pop(1);
        final_record = [];
        row_array = [];
        //remove loading sign
        $("#csv_parsing").hide();
    }

    $scope.strip_char = function(data) {
        return data.replace(new RegExp('^'+$scope.current.delimiter+'+|'+$scope.current.delimiter+'+$', 'g'), '');
    }
    $scope.column_map = function(col,option) {
        map_overwrite = true;
        for(var prop in $scope.current.map) {
            if($scope.current.map[prop].value === option.value) {
                if(confirm("Are you sure you want to change the mapping for "+option.name+" to current column?")) {
                    $scope.column_unmap(prop,option);
                } else {
                    map_overwrite = false;
                }
                break;
            }
        }
        if(map_overwrite) {
            $scope.current.map[col] = option;
            $(".csv-preview-" + option.value).addClass("disabled");
        }
    }

    $scope.column_unmap = function(col) {
        value = "";
        if("value" in $scope.current.map[col]) {
            value = $scope.current.map[col].value;
        }
        $scope.current.map[col] = $scope.csvimporter.default_map;
        $(".csv-preview-" + value).removeClass("disabled");
    }

    }]);
