groovepacks_controllers.
controller('showStoresCtrl', [ '$scope', '$http', '$timeout', '$routeParams', '$location', '$route', '$cookies',
    function( $scope, $http, $timeout, $routeParams, $location, $route, $q, $cookies) {

        $scope.current_page="show_stores";
        $scope.$on("fileSelected", function (event, args) {
            $scope.$apply(function () {
                $scope.newStore[args.name] = args.file;
            });
            $("input[type='file']").val('');
            if(args.name == 'orderfile') {
                $scope.newStore.type = 'order'
            } else {
                $scope.newStore.type = 'product'
            }
            $scope.submit();
        });

    	$http.get('/home/userinfo.json').success(function(data){
    		$scope.username = data.username;
    	});
        
        $scope.orderimport_type = 'apiimport';
        $scope.productimport_type = 'apiimport';
        $scope.ebay_show_signin_url = true;
    	$http.get('/store_settings/storeslist.json').success(function(data) {
    		$scope.stores = data;
    		$scope.reverse = false;
            $scope.newUser = {};
            $scope.redirect = $routeParams.redirect;
            console.log($routeParams);
            if ($scope.redirect)
            {
                if ($routeParams.editstatus=='true')
                {
                    $scope.edit_status = $routeParams.editstatus; 
                    $scope.retrieveandupdateusertoken($routeParams.storeid); 
                    $scope.newStore = new Object();
                    $scope.newStore.id = $routeParams.storeid;
                    $scope.newStore.name = $routeParams.name;
                    $scope.newStore.status = $routeParams.status;
                    $scope.newStore.store_type = $routeParams.storetype;
                    $('#createStore').modal('show');   
                }
                else
                {
                    $scope.ebayuserfetchtoken();
                    $scope.newStore = new Object();
                    $scope.newStore.name = $routeParams.name;
                    $scope.newStore.status = $routeParams.status;
                    $scope.newStore.store_type = $routeParams.storetype;
                    $('#createStore').modal('show');   
                }
            }
            else
            {   
            // $http.get('/store_settings/getebaysigninurl.json').success(function(data) {
            //     if (data.ebay_signin_url_status)
            //     {
            //     $scope.ebay_signin_url = data.ebay_signin_url;
            //     $scope.ebay_signin_url_status = data.ebay_signin_url_status;
            //     $scope.ebay_sessionid = data.ebay_sessionid;
            //     }

            //     }).error(function(data) {
            //         $scope.ebay_signin_url_status = false;
            //     });
            }
    	}).error(function(data) {
    		$scope.error_msg = "There was a problem retrieving stores list";
    		$scope.show_error = true;
    	});

        $scope.retrieveandupdateusertoken = function(id) {
            $http.get('/store_settings/updateebayusertoken.json?storeid='+id).success(function(data) {
                if (data.status)
                {
                    $scope.ebay_show_signin_url = false;

                }
                }).error(function(data) {
                    $scope.ebay_show_signin_url = true;
                });
        }


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
                    $scope.showstoreupdate_status = true;
                    $scope.storeupdate_message = 'Store has been successfully updated.';
    				var type = $scope.newStore.type;
                    if ($scope.newStore.store_type == 'CSV')
                    {
                        $scope.newStore = {};
                        $('#createStore').modal('hide');
                    }


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
                    $scope.edit_status = true;

                    //Use FileReader API here if it exists (post prototype feature)
                    if(data.csv_import && data.store_id) {
                        $http.get('/store_settings/csvImportData.json?id='+data.store_id+'&type='+type).success(function(data) {
                            $scope.csv_init(data);
                            $('#importCsv').modal('show');

                        }).error(function(data) {
                            $scope.error_msg = "There was a problem retrieving stores list.";
                            $scope.show_error = true;
                        });
                    }
    			}
    		});
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
    $scope.ebayuserfetchtoken = function(session_id) {
        $http.get('/store_settings/ebayuserfetchtoken.json').success(function(data){
            if (data.status)
            {
            $scope.ebay_show_signin_url = false;
            $http.post('/store_settings/createStore.json', $scope.newStore).success(function(data) {
                if(!data.status)
                {
                    $scope.error_msgs = data.messages;
                    $scope.show_error_msgs = true;
                }
                else
                {
                    $scope.newStore.id = data.storeid
                    $scope.edit_status = true;
                }
            });           
            }
            //console.log(data);
        });
    }

    $scope.disconnect_ebay_seller = function() {
        $http.get('/store_settings/deleteebaytoken.json?storeid='+$scope.newStore.id).success(function(data){
                    if (data.status)
                    {
                        $scope.getebaysigninurl();      
                    }
                    //console.log(data);
                });
    }

    $scope.getebaysigninurl = function(){
        $http.get('/store_settings/getebaysigninurl.json').success(function(data) {
                        if (data.ebay_signin_url_status)
                        {
                        $scope.ebay_signin_url = data.ebay_signin_url;
                        $scope.ebay_signin_url_status = data.ebay_signin_url_status;
                        $scope.ebay_sessionid = data.ebay_sessionid;
                        $scope.ebay_show_signin_url = true;
                        }

                        }).error(function(data) {
                            $scope.ebay_signin_url_status = false;
                        });       
    }
    $scope.getstoreinfo = function(id) {
            /* update the server with the changed status */
            $http.get('/store_settings/getstoreinfo.json?id='+id).success(function(data){
                $scope.importproduct_status ="";
                $scope.importorder_status ="";
                $scope.importproductstatus_show = false;
                $scope.importorderstatus_show = false;
                        if (data.status)
                        { 
                            $scope.newStore = data.store;
                            $scope.edit_status = true;
                            if (data.credentials.status == true)
                            {
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
                                $scope.newStore.ebay_auth_token = data.credentials.ebay_credentials.auth_token;  
                                $scope.newStore.productebay_auth_token = data.credentials.ebay_credentials.productauth_token;  
                                $scope.newStore.import_products = data.credentials.ebay_credentials.import_products; 
                                $scope.newStore.import_images = data.credentials.ebay_credentials.import_images;
                                if($scope.newStore.ebay_auth_token != '')
                                {
                                    $scope.ebay_show_signin_url = false; 
                                }
                                else
                                {
                                    $scope.ebay_show_signin_url = true; 
                                    $scope.getebaysigninurl(); 
                                }

                            }
                            if (data.store.store_type == 'Amazon')
                            {
                                $scope.newStore.marketplace_id = data.credentials.amazon_credentials.marketplace_id; 
                                $scope.newStore.merchant_id = data.credentials.amazon_credentials.merchant_id;


                                $scope.newStore.productmarketplace_id = data.credentials.amazon_credentials.productmarketplace_id; 
                                $scope.newStore.productmerchant_id = data.credentials.amazon_credentials.productmerchant_id;        
                                $scope.newStore.import_products = data.credentials.amazon_credentials.import_products; 
                                $scope.newStore.import_images = data.credentials.amazon_credentials.import_images;
                                $scope.newStore.productreport_id = data.credentials.amazon_credentials.productreport_id;
                                $scope.newStore.productgenerated_report_id = data.credentials.amazon_credentials.productgenerated_report_id   
                            }

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
        $scope.redirect = false;
        $scope.newStore = {};
        $scope.ebay_show_signin_url = true;
        $scope.newStore.status = 1;
        $http.get('/store_settings/getebaysigninurl.json').success(function(data) {
            if (data.ebay_signin_url_status)
            {
            $scope.ebay_signin_url = data.ebay_signin_url;
            $scope.ebay_signin_url_status = data.ebay_signin_url_status;
            $scope.ebay_sessionid = data.ebay_sessionid;
            }

            }).error(function(data) {
                $scope.ebay_signin_url_status = false;
            });
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
                    $scope.newStore.productebay_auth_token = $scope.newStore.ebay_auth_token;        
                }
                if ($scope.newStore.store_type == 'Amazon')
                {
                    $scope.newStore.productmarketplace_id = $scope.newStore.marketplace_id; 
                    $scope.newStore.productmerchant_id = $scope.newStore.merchant_id;      
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
                    $scope.newStore.productebay_auth_token = "";    
                }
                if ($scope.newStore.store_type == 'Amazon')
                {
                    $scope.newStore.productmarketplace_id = ""; 
                    $scope.newStore.productmerchant_id = "";      
                }
        }
    }

    $scope.import_orders = function(report_id) {
            $scope.importorder_status = "Import in progress";
            $scope.importorderstatus_show = true;
            $http.get('/orders/importorders/'+$scope.newStore.id+'.json').success(function(data){
                //console.log(data);
                if (data.status)
                {
                $scope.importorder_status="Successfully imported "+data.success_imported+" of "+data.total_imported+" orders. "
                    +data.previous_imported+" orders were previously imported";
                }
                else
                {
                $scope.importorder_status = "Import failed. Please check your credentials."
                }
            //$scope.importproduct_status = "Import completed";
            }).error(function(data) {
                $scope.importorder_status = "Import failed. Please check your credentials."
            });      
    }

    $scope.import_products = function(report_id) {
            $scope.importproduct_status = "Import in progress";
            $scope.importproductstatus_show = true;
            $http.get('/products/importproducts/'+$scope.newStore.id+'.json?reportid='+report_id).success(function(data){
                //console.log(data);
                if (data.status)
                {
                $scope.importproduct_status="Successfully imported "+data.success_imported+" of "+data.total_imported+" products. "+
                        +data.previous_imported+" products were previously imported";;
                }
                else
                {
                $scope.importproduct_status = "Import failed. Please check your credentials"
                }
            //$scope.importproduct_status = "Import completed";
            }).error(function(data) {
                $scope.importproduct_status = "Import failed. Please check your credentials"
            });      
    }

    $scope.request_import_products = function() {
            $scope.importproduct_status = "Import request in progress";
            $scope.importproductstatus_show = true;
            $http.get('/products/requestamazonreport/'+$scope.newStore.id+'.json').success(function(data){
                console.log(data);
                if (data.status)
                {
                $scope.importproduct_status="Report for product import has been submitted. "+
                    "Please check status in few minutes to import the products";
                $scope.newStore.productgenerated_report_id = '';
                $scope.newStore.productreport_id = data. requestedreport_id;
                }
                else
                {
                $scope.importproduct_status = "Report request failed. Please check your credentials."
                }
            //$scope.importproduct_status = "Import completed";
            }).error(function(data) {
                $scope.importproduct_status = "Report request failed. Please check your credentials."
            });  
    }
    $scope.check_request_import_products =function() {
            $scope.importproduct_status = "Checking status of the request";
            $scope.importproductstatus_show = true;
            $http.get('/products/checkamazonreportstatus/'+$scope.newStore.id+'.json').success(function(data){
                //console.log(data);
                if (data.status)
                {
                $scope.importproduct_status= data.report_status;
                $scope.newStore.productgenerated_report_id = data.generated_report_id;
                }
                else
                {
                $scope.importproduct_status = "Error checking status."
                }
            //$scope.importproduct_status = "Import completed";
            }).error(function(data) {
                $scope.importproduct_status = "Error checking status. Please try again later"
            });  
    }
    /* Import orders from all the active stores */
    $scope.import_all_orders =function() {
            $('#importOrders').modal('show');
            /* Get all the active stores */
            $http.get('/store_settings/getactivestores.json').success(function(data) {
                if (data.status)
                {
                    //console.log("data status");
                    $scope.active_stores = [];

                    for (var i = 0; i < data.stores.length; i++)
                    {
                            var activeStore = new Object();
                            activeStore.info = data.stores[i];
                            activeStore.message="";
                            activeStore.status="in_progress";
                            $scope.active_stores.push(activeStore); 
                    }
                    /* for each store send a import request */
                    for (var i = 0; i < $scope.active_stores.length; i++)
                    {
                       //$scope.active_stores[i].status="in_progress";

                        $http.get('/orders/importorders/'+$scope.active_stores[i].info.id+'.json?activestoreindex='+i).success(
                            function(orderdata){

                            if (orderdata.status)
                            {
                            $scope.active_stores[orderdata.activestoreindex].status="completed";
                            $scope.active_stores[orderdata.activestoreindex].message = "Successfully imported "+orderdata.success_imported+
                                    " of "+orderdata.total_imported+" orders. "
                                +orderdata.previous_imported+" orders were previously imported";
                            }
                            else
                            {
                            $scope.active_stores[orderdata.activestoreindex].status="failed";
                            $scope.active_stores[orderdata.activestoreindex].message = "Import failed. Please check your credentials."
                            }
                        }).error(function(data) {
                            $scope.active_stores[i].status="failed";
                            $scope.active_stores[i].message = orderdata.messages;
                            });    
                    }
                     
                }
                else
                {
                    console.log("data status false");
                $scope.message = "Getting active stores returned error.";
                }
            }).error(function(data) {
                $scope.message = "Getting active stores failed.";
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
        $scope.check_disable();
    }

    $scope.check_disable = function () {
        $(".csv-preview-option").removeClass("disabled");
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
            $scope.check_disable();
        }
    }

    $scope.column_unmap = function(col) {
        value = "";
        if("value" in $scope.current.map[col]) {
            value = $scope.current.map[col].value;
        }
        $scope.current.map[col] = $scope.csvimporter.default_map;
        $scope.check_disable();
    }

    $scope.close_modal = function() {
        $scope.newStore = {};
        $('#createStore').modal('hide');
        $scope.showstoreupdate_status = false;
        $scope.storeupdate_message = '';
    }
    }]);
