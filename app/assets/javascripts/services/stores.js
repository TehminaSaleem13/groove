groovepacks_services.factory('stores',['$http','notification','$filter',function($http,notification,$filter) {

    var success_messages = {
        update_status: "Status updated Successfully",
        delete:"Deleted Successfully",
        duplicate: "Duplicated Successfully"
    };
    var get_default = function() {
        return {
            list: [],
            single: {},
            ebay:{},
            import:{
               order:{},
               product:{}
            },
            types: {},
            current: 0,
            setup:{
                sort: "",
                order: "DESC",
                search: '',
                select_all: false,
                //used for updating only
                status:'',
                storeArray:[]
            }
        };
    };
    //Setup related function
    var update_setup = function (setup,type,value) {
        if(type =='sort') {
            if(setup[type] == value) {
                if(setup.order == "DESC") {
                    setup.order = "ASC";
                } else {
                    setup.order = "DESC";
                }
            } else {
                setup.order = "DESC";
            }
        }
        setup[type] = value;
        return setup;
    };

    //list related functions
    var get_list = function(object) {
        var result = [];
        return $http.get('/store_settings/storeslist.json').success(
            function(data) {
                result = $filter('filter')(data,object.setup.search);
                result = $filter('orderBy')(result,object.setup.sort,(object.setup.order=='DESC'));
                object.list = result;
            }
        ).error(notification.server_error);
    };

    var update_list = function(action,stores) {
        if(["update_status","delete","duplicate"].indexOf(action) != -1) {
            stores.setup.storeArray = [];
            for(var i = 0;  i< stores.list.length; i++) {
                if (stores.list[i].checked == true) {
                    stores.setup.storeArray.push({id: stores.list[i].id,status:(stores.setup.status =='active')});
                }
            }
            var url = '';
            if(action == "delete") {
                url = '/store_settings/deletestore.json';
            } else if(action =="duplicate") {
                url = '/store_settings/duplicatestore.json';
            } else if(action == "update_status") {
                url = '/store_settings/changestorestatus.json';
            }

            return $http.post(url,stores.setup.storeArray).success(function(data) {
                if(data.status) {
                    stores.setup.select_all =  false;
                    notification.notify(success_messages[action],1);
                } else {
                    notification.notify(data.messages,0);
                }
            }).error(notification.server_error);
        }
    };


    //single store related functions
    var get_single = function(id,stores) {
        return $http.get('/store_settings/getstoreinfo.json?id='+id).success(function(data) {
            stores.single = {};
            stores.import.product.status ="";
            stores.import.order.status ="";
            stores.import.product.status_show = false;
            stores.import.order.status_show = false;
            if(data.status) {
                stores.single = data.store;
                if(data.credentials.status == true) {
                    if(data.store.store_type == 'Magento') {
                        stores.single.host = data.credentials.magento_credentials.host;
                        stores.single.username = data.credentials.magento_credentials.username;
                        stores.single.password = data.credentials.magento_credentials.password;
                        stores.single.api_key = data.credentials.magento_credentials.api_key;

                        stores.single.producthost = data.credentials.magento_credentials.producthost;
                        stores.single.productusername = data.credentials.magento_credentials.productusername;
                        stores.single.productpassword = data.credentials.magento_credentials.productpassword;
                        stores.single.productapi_key = data.credentials.magento_credentials.productapi_key;
                        stores.single.import_products = data.credentials.magento_credentials.import_products;
                        stores.single.import_images = data.credentials.magento_credentials.import_images;

                    } else if(data.store.store_type == 'Ebay') {
                        stores.single.ebay_auth_token = data.credentials.ebay_credentials.auth_token;
                        stores.single.productebay_auth_token = data.credentials.ebay_credentials.productauth_token;
                        stores.single.import_products = data.credentials.ebay_credentials.import_products;
                        stores.single.import_images = data.credentials.ebay_credentials.import_images;
                        if(stores.single.ebay_auth_token != '' && stores.single.ebay_auth_token != null) {
                            stores.ebay.show_url = false;
                        } else {
                            stores.ebay.show_url = true;
                            ebay_sign_in_url(stores);
                        }

                    } else if(data.store.store_type == 'Amazon') {
                        stores.single.marketplace_id = data.credentials.amazon_credentials.marketplace_id;
                        stores.single.merchant_id = data.credentials.amazon_credentials.merchant_id;

                        stores.single.productmarketplace_id = data.credentials.amazon_credentials.productmarketplace_id;
                        stores.single.productmerchant_id = data.credentials.amazon_credentials.productmerchant_id;
                        stores.single.import_products = data.credentials.amazon_credentials.import_products;
                        stores.single.import_images = data.credentials.amazon_credentials.import_images;
                        stores.single.show_shipping_weight_only = data.credentials.amazon_credentials.show_shipping_weight_only;
                        stores.single.productreport_id = data.credentials.amazon_credentials.productreport_id;
                        stores.single.productgenerated_report_id = data.credentials.amazon_credentials.productgenerated_report_id
                    } else if(data.store.store_type == 'Shipstation') {
                        stores.single.username = data.credentials.shipstation_credentials.username;
                        stores.single.password = data.credentials.shipstation_credentials.password;
                    }

                }
            }
        }).error(notification.server_error);
    };

    var create_update_single = function(stores,auto) {
        if(typeof auto !== "boolean") {
            auto = true;
        }
        return $http({
            method: 'POST',
            headers: { 'Content-Type': undefined },
            url:'/store_settings/createUpdateStore.json',
                transformRequest: function (data) {
                var request = new FormData();
                for (var key in data) {
                    if(data.hasOwnProperty(key)) {
                        request.append(key,data[key]);
                    }
                }
                return request;
            },
            data: stores.single
        }).success(function(data) {
            if(data.status && data.store_id) {
                if(!auto) {
                    notification.notify("Successfully Updated",1);
                }
            } else {
                notification.notify(data.messages,0);
            }
        }).error(notification.server_error);
    };

    //ebay related functions
    var ebay_sign_in_url = function(stores) {
        return $http.get('/store_settings/getebaysigninurl.json').success(function(data) {
            if (data.ebay_signin_url_status) {
                stores.ebay.signin_url = data.ebay_signin_url;
                stores.ebay.signin_url_status = data.ebay_signin_url_status;
                stores.ebay.sessionid = data.ebay_sessionid;
                stores.ebay.current_tenant = data.current_tenant;
            }
        }).error(function(data) {
            stores.ebay.signin_url_status = false;
            notification.server_error(data);
        });
    };

    var ebay_token_fetch = function(stores) {
        return $http.get('/store_settings/ebayuserfetchtoken.json').success(function(data){
            if(data.status) {
                stores.ebay.show_url = false;
            }
        }).error(notification.server_error);
    };

    var ebay_token_delete = function(stores) {
        return $http.get('/store_settings/deleteebaytoken.json?storeid='+stores.single.id).success(function(data){
            if (data.status) {
                ebay_sign_in_url(stores);
            }
        }).error(notification.server_error);
    };

    var ebay_token_update = function(stores,id) {
        return $http.get('/store_settings/updateebayusertoken.json?storeid='+id).success(function(data) {
            if (data.status) {
                stores.ebay.show_url = false;
            }
        }).error(notification.server_error);
    };

    //Import related functions
    var import_products = function(stores,report_id) {
        return $http.get('/products/importproducts/'+stores.single.id+'.json?reportid='+report_id).success(function(data){
            if (data.status) {
                stores.import.product.status="Successfully imported "+data.success_imported+" of "+data.total_imported+
                                             " products. "+data.previous_imported+" products were previously imported";
            } else {
                stores.import.product.status = "";
                for (var j=0; j< data.messages.length; j++) {
                    stores.import.product.status += data.messages[j]+" ";
                }
            }
        }).error(function(data) {
            stores.import.product.status = "Import failed. Please check your credentials";
        });
    };

    var import_orders = function(stores) {
        return  $http.get('/orders/importorders/'+stores.single.id+'.json').success(function(data){
            if (data.status) {
                stores.import.order.status = "Successfully imported "+data.success_imported+" of "+data.total_imported+
                                             " orders. " +data.previous_imported+" orders were previously imported";
            } else {
                stores.import.order.status = "";
                for (var j=0; j< data.messages.length; j++) {
                    stores.import.order.status += data.messages[j]+" ";
                }
            }
        }).error(function(data) {
            stores.import.order.status = "Import failed. Please check your credentials.";
        });
    };

    var import_amazon_request = function(stores) {
        return $http.get('/products/requestamazonreport/'+stores.single.id+'.json').success(function(data){
            if (data.status) {
                stores.import.product.status="Report for product import has been submitted. "+
                                             "Please check status in few minutes to import the products";
                stores.single.productgenerated_report_id = '';
                stores.single.productreport_id = data. requestedreport_id;
            } else {
                stores.import.product.status = "Report request failed. Please check your credentials."
            }
        }).error(function(data) {
            stores.import.product.status = "Report request failed. Please check your credentials.";
        });
    };

    var import_amazon_check = function(stores) {
        return $http.get('/products/checkamazonreportstatus/'+stores.single.id+'.json').success(function(data){
            if (data.status) {
                stores.import.product.status= data.report_status;
                stores.single.productgenerated_report_id = data.generated_report_id;
            } else {
                stores.import.product.status = "Error checking status."
            }
        }).error(function(data) {
            stores.import.product.status = "Error checking status. Please try again later";
        });
    };

    //csv related functions
    var csv_import_data = function(stores,id) {
        return $http.get('/store_settings/csvImportData.json?id=' + id + '&type='+ stores.single.type).
            error(notification.server_error);
    };

    var csv_do_import = function(csv) {
        return $http.post('store_settings/csvDoImport.json',csv.current).success(function(data){
            if(data.status) {
                notification.notify("CSV imported successfully",1);
                csv.current = {};
                csv.importer = {};
            } else {
                notification.notify(data.messages,0);
                csv.current.rows = csv.current.rows + data.last_row;
            }
        }).error(notification.server_error);
    };


    //Public facing API
    return {
        model: {
            get:get_default
        },
        setup: {
            update:update_setup
        },
        list: {
            get: get_list,
            update: update_list
        },
        single: {
            get: get_single,
            update:create_update_single
        },
        ebay: {
              sign_in_url: {
                  get: ebay_sign_in_url
              },
              user_token: {
                  fetch: ebay_token_fetch,
                  delete: ebay_token_delete,
                  update:ebay_token_update
              }
        },
        import: {
            products: import_products,
            orders: import_orders,
            amazon: {
                request: import_amazon_request,
                check: import_amazon_check
            }
        },
        csv: {
             import: csv_import_data,
             do_import: csv_do_import
        }
    };
}]);
