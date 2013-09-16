groovepacks_controllers.
controller('showStoresCtrl', [ '$scope', '$http', '$timeout', '$routeParams', '$location', '$route', '$cookies',
    function( $scope, $http, $timeout, $routeParams, $location, $route, $q, $cookies) {

        $scope.current_page="show_stores";
        $scope.$on("fileSelected", function (event, args) {
            $scope.$apply(function () {
                $scope.newStore[args.name] = args.file;
            });
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
        $scope.current = {};
        $scope.current.rows = 1;
        $scope.current.fix_width = 0;
        $scope.current.delimiter = '"';
        $scope.current.fixed_width = 4;
        $scope.current.separator = "comma";
        $scope.current.map = {};
        $scope.current.custom_separator = ""
        $scope.csvimporter.separator_map = {
            comma: ',' ,
            semicolon: ';' ,
            tab: '\t',
            space: ' ',
            other: $scope.current.custom_separator
        };
        $scope.csvimporter.default_map = {value:'none', name:"Unmapped"};
        if("product" in data) {
            $scope.csvimporter.product = data["product"];
            $scope.csvimporter.product.map_options = [
                { value:"sku" , name:"SKU"},
                { value: "product_name", name: "Product Name"},
                { value: "category_name", name: "Category Name"},
                { value: "inv_wh1", name: "Inventory"},
                { value: "product_images", name: "Product Images"},
                { value: "location_primary", name: "Location/Bin"},
                { value: "barcode", name: "Barcode Value"}
            ]
            $scope.csvimporter.current_type = data["product"];
            $scope.csvimporter.type = "product";
        }
        if("order" in data) {
            $scope.csvimporter.order = data["order"];
            $scope.csvimporter.order.map_options = [
                { value: "increment_id", name: "Order number"},
                { value: "order_placed_time", name: "Order placed"},
                { value: "sku", name: "SKU"},
                { value: "customer_comments", name: "Customer Comments"},
                { value: "qty", name: "Qty"},
                { value: "price", name: "Price"},
                { value: "firstname", name: "First name"},
                { value: "lastname", name: "Last name"},
                { value: "email", name: "Email"},
                { value: "address_1", name: "Address 1"},
                { value: "address_2", name: "Address 2"},
                { value: "city", name: "City"},
                { value: "state", name: "State"},
                { value: "postcode", name: "Postal Code"},
                { value: "country", name: "Country"},
                { value: "method", name: "Shipping Method"}
            ]
            $scope.csvimporter.current_type = data["order"];
            $scope.csvimporter.type = "order";
        }
        $scope.parse();
    }

    $scope.parse = function() {
        $scope.current.data = [];
        $scope.current.empty_cols = [];
        in_entry = false;
        secondary_split = [];
        initial_split = $scope.csvimporter.current_type.data.split(/\r?\n/g);
        tmp_record = '';
        row_array = [];
        $scope.csvimporter.separator_map.other=$scope.current.custom_separator;
        separator = $scope.csvimporter.separator_map[$scope.current.separator];
        final_record = [];
        maxcolumns = 0;
        for( i in initial_split) {
            if($scope.current.fix_width == 1) {
                $scope.current.data.push($.map(initial_split[i].chunk($scope.current.fixed_width),function(val,ind) {return val.trimmer($scope.current.delimiter);} ));
            } else {
                secondary_split = initial_split[i].split(separator);
                for(j in secondary_split) {
                    if(secondary_split[j].charAt(0) == $scope.current.delimiter && secondary_split[j].charAt(secondary_split[j].length -1) != $scope.current.delimiter) {
                        in_entry = true;
                    } else if(secondary_split[j].charAt(secondary_split[j].length -1) == $scope.current.delimiter) {
                        in_entry = false;
                    }

                    if(in_entry) {
                        tmp_record += secondary_split[j]+separator;
                    } else {
                        row_array.push((tmp_record + secondary_split[j]).trimmer($scope.current.delimiter));
                        tmp_record =$scope.current.delimiter;
                    }
                }
                if(!in_entry) {
                    if(maxcolumns < row_array.length) {
                        maxcolumns = row_array.length;
                    }
                    final_record.push(row_array);
                    row_array = [];
                } else {
                    tmp_record += "\r\n";
                }
            }
        }
        for(i = 0; i< maxcolumns; i++) {
            $scope.current.empty_cols.push(i);
        }
        $scope.current.data = final_record.slice($scope.current.rows-1);
        $scope.current.data.pop(1);
        final_record = [];
        row_array = [];
    }

    $scope.strip_char = function(data) {
        return data.replace(new RegExp('^'+$scope.current.delimiter+'+|'+$scope.current.delimiter+'+$', 'g'), '');
    }
    $scope.column = function(row,col) {
        if( row in $scope.current.data && col in $scope.current.data[row]) {
            return $scope.current.data[row][col];
        }
        return "";

    }
    $scope.column_map = function(col,option) {
        map = true;
        for(var prop in $scope.current.map) {
            if($scope.current.map[prop] === option) {
                if(confirm("Are you sure you want to change the mapping for "+option.name+" to current column?")) {
                    $scope.column_unmap(prop,option);
                } else {
                    map = false;
                }
                break;
            }
        }
        if(map) {
            $scope.current.map[col] = option;
            $(".csv-preview-" + option.value).addClass("disabled");
        }
    }

    $scope.column_unmap = function(col,option) {
        $scope.current.map[col] = $scope.csvimporter.default_map;
        $(".csv-preview-" + option.value).removeClass("disabled");
    }

    }]);