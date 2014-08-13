groovepacks_controllers.controller('storeSingleModal', [ '$scope', 'store_data', '$state', '$stateParams','$modal',
                             '$modalInstance', '$timeout', 'hotkeys', 'stores','warehouses','notification',
function(scope, store_data, $state, $stateParams, $modal, $modalInstance, $timeout, hotkeys, stores, warehouses, notification) {
    var myscope = {};

    /**
     * Public methods
     */

    scope.ok = function() {
        $modalInstance.close("ok-button-click");
    };
    scope.cancel = function () {
        $modalInstance.dismiss("cancel-button-click");
    };

    scope.update = function(reason) {
        if(reason == "cancel-button-click") {
            myscope.rollback();
        } else if(typeof scope.stores.single.id != "undefined") {
            scope.update_single_store(false);
        }
    };

    scope.disconnect_ebay_seller = function() {
        stores.ebay.user_token.delete(stores);
    };

    scope.import_orders = function(report_id) {
        scope.stores.import.order.status = "Import in progress";
        scope.stores.import.order.status_show = true;
        stores.import.orders(scope.stores);
    };

    scope.import_products = function(report_id) {
        scope.stores.import.product.status = "Import in progress";
        scope.stores.import.product.status_show = true;
        stores.import.products(scope.stores,report_id);
    };

    scope.request_import_products = function() {
        scope.stores.import.product.status = "Import request in progress";
        scope.stores.import.product.status_show = true;
        stores.import.amazon.request(scope.stores);
    };

    scope.check_request_import_products = function() {
        scope.stores.import.product.status = "Checking status of the request";
        scope.stores.import.product.status_show = true;
        stores.import.amazon.check(scope.stores);
    };

    scope.copydata =function(event) {
        if(event) {
            if(scope.stores.single.store_type == 'Magento') {
                scope.stores.single.producthost = scope.stores.single.host;
                scope.stores.single.productusername = scope.stores.single.username;
                scope.stores.single.productpassword = scope.stores.single.password;
                scope.stores.single.productapi_key = scope.stores.single.api_key;
            } else if(scope.stores.single.store_type == 'Ebay') {
                scope.stores.single.productebay_auth_token = scope.stores.single.ebay_auth_token;
            } else if (scope.stores.single.store_type == 'Amazon') {
                scope.stores.single.productmarketplace_id = scope.stores.single.marketplace_id;
                scope.stores.single.productmerchant_id = scope.stores.single.merchant_id;
            }else if (scope.stores.single.store_type == 'Shipstation') {
                scope.stores.single.productusername = scope.stores.single.username;
                scope.stores.single.productpassword = scope.stores.single.password;
            }
        } else {
            if (scope.stores.single.store_type == 'Magento') {
                scope.stores.single.producthost = "";
                scope.stores.single.productusername = "";
                scope.stores.single.productpassword = "";
                scope.stores.single.productapi_key = "";
            } else if (scope.stores.single.store_type == 'Ebay') {
                scope.stores.single.productebay_auth_token = "";
            } else if (scope.stores.single.store_type == 'Amazon') {
                scope.stores.single.productmarketplace_id = "";
                scope.stores.single.productmerchant_id = "";
            }else if (scope.stores.single.store_type == 'Shipstation') {
                scope.stores.single.productusername = "";
                scope.stores.single.productpassword = "";
            }
        }
    };

    myscope.store_single_details = function(id,new_rollback) {
        for(var i =0; i< scope.stores.list.length; i++) {
            if(scope.stores.list[i].id == id) {
                scope.stores.current = parseInt(i);
                break;
            }
        }
        return stores.single.get(id,scope.stores).then(function(response) {
            if(response.data.status) {
                scope.edit_status = true;
                if(typeof new_rollback == 'boolean' && new_rollback ){
                    myscope.single = {};
                    angular.copy(scope.stores.single,myscope.single);
                }
            }
        });
    };

    scope.update_single_store = function(auto) {
        if(typeof scope.stores.single['name'] != "undefined"
           && scope.stores.single.name != ""
           && typeof scope.stores.single.store_type != "undefined"
           && scope.stores.single.store_type != "") {
            return stores.single.update(scope.stores,auto).success(function(data){
                if(data.status && data.store_id) {
                    if(typeof scope.stores.single['id'] == "undefined") {
                        myscope.store_single_details(data.store_id,true);
                    }
                    if(!auto) {
                        //Use FileReader API here if it exists (post prototype feature)
                        if (data.csv_import && data.store_id) {
                            var csv_modal = $modal.open({
                                templateUrl: '/assets/views/modals/settings/stores/csv_import.html',
                                controller: 'csvSingleModal',
                                size:'lg',
                                resolve: {
                                    store_data: function(){return scope.stores}
                                }
                            });
                            csv_modal.result.finally(function() {
                                myscope.store_single_details(scope.stores.single.id,false);
                            });
                        }
                    }
                }
            });
        }
    };

    myscope.rollback = function() {
        scope.stores.single = {};
        angular.copy(myscope.single,scope.stores.single);
        scope.update_single_store();
    };

    myscope.up_key = function(event) {
        event.preventDefault();
        event.stopPropagation();
        if($state.includes('settings.stores.single')) {
            if(scope.stores.current > 0) {
                myscope.load_item(scope.stores.current -1);
            } else {
                alert("Already at the top of the list");
            }
        }
    };

    myscope.down_key = function (event) {
        event.preventDefault();
        event.stopPropagation();
        if($state.includes('settings.stores.single')) {
            if(scope.stores.current < scope.stores.list.length - 1) {
                myscope.load_item(scope.stores.current + 1);
            } else {
                alert("Already at the bottom of the list");
            }
        }
    };

    myscope.load_item = function(id) {
        var newStateParams = angular.copy($stateParams);
        newStateParams.storeid = ""+scope.stores.list[id].id;
        myscope.store_single_details(scope.stores.list[id].id, true);
        $state.go($state.current.name, newStateParams);
    };


    myscope.init = function() {
        scope.stores = store_data;
        scope.stores.single = {};
        scope.stores.ebay = {};
        scope.stores.import = {
            order:{},
            product: {}
        };
        scope.stores.types = {};
        scope.warehouses = warehouses.model.get();
        warehouses.list.get(scope.warehouses).then(function() {
            if(typeof scope.stores.single['inventory_warehouse_id'] != "number") {
                for(var i=0; i<scope.warehouses.list.length; i++) {
                    if (scope.warehouses.list[i].info.is_default) {
                        scope.stores.single.inventory_warehouse_id = scope.warehouses.list[i].info.id;
                        //console.log(scope.stores.single);
                        break;
                    }
                }
            }
        });

        scope.stores.types = {
            Magento: {
                name: "Magento",
                file: "/assets/views/modals/settings/stores/magento.html"
            },
            Ebay: {
                name: "Ebay",
                file: "/assets/views/modals/settings/stores/ebay.html"
            },
            Amazon: {
                name: "Amazon",
                file: "/assets/views/modals/settings/stores/amazon.html"
            },
            CSV: {
                name: "CSV",
                file: "/assets/views/modals/settings/stores/csv.html"
            },
            Shipstation: {
                name: "Shipstation",
                file: "/assets/views/modals/settings/stores/shipstation.html"
            }
        };


        //Determine create/ edit/ redirect call

        scope.stores.import.order.type = 'apiimport';
        scope.stores.import.product.type = 'apiimport';
        scope.stores.ebay.show_url = true;
        if($state.includes('settings.stores.create')) {
            scope.edit_status = false;
            scope.redirect = false;
            scope.stores.single.status = 1;
            scope.stores.ebay.show_url = true;
            stores.ebay.sign_in_url.get(scope.stores);
            scope.stores.single.import_images = true;
            scope.stores.single.import_products = true;
        } else {
            scope.edit_status = true;
            scope.redirect = ($stateParams.redirect || ($stateParams.action == "create"));
            if(scope.redirect) {
                if( typeof $stateParams['editstatus'] != 'undefined' && $stateParams.editstatus == 'true') {
                    scope.edit_status = $stateParams.editstatus;
                    stores.ebay.user_token.update(scope.stores, $stateParams.storeid);

                    scope.stores.single.id = $stateParams.storeid;

                    scope.stores.single.name = $stateParams.name;

                    scope.stores.single.status = ($stateParams.status =='true');
                    scope.stores.single.store_type = $stateParams.storetype;

                    scope.stores.single.inventory_warehouse_id = parseInt($stateParams.inventorywarehouseid);
                    scope.stores.single.import_images = ($stateParams.importimages == 'true');
                    scope.stores.single.import_products = ($stateParams.importproducts == 'true');
                    scope.stores.single.thank_you_message_to_customer = $stateParams.messagetocustomer;
                    scope.stores.single.username = $stateParams.username;
                    scope.stores.single.password = $stateParams.password;
                } else {
                    scope.stores.single.name = $stateParams.name;
                    scope.stores.single.status = ($stateParams.status ==true);
                    scope.stores.single.store_type = $stateParams.storetype;

                    scope.stores.single.inventory_warehouse_id = parseInt($stateParams.inventorywarehouseid);
                    scope.stores.single.import_images = ($stateParams.importimages == 'true');
                    scope.stores.single.import_products = ($stateParams.importproducts == 'true');
                    scope.stores.single.thank_you_message_to_customer = $stateParams.messagetocustomer;
                    scope.stores.single.username = $stateParams.username;
                    scope.stores.single.password = $stateParams.password;
                    stores.ebay.user_token.fetch(scope.stores).then(function(response){
                        if(response.data.status) {
                            scope.update_single_store();
                        }
                    });
                }
                if(typeof scope.stores.single.status == "undefined") {
                    scope.stores.single.status = 1;
                }
            } else {
                myscope.store_single_details($stateParams.storeid,false);
            }

        }


        scope.$on("fileSelected", function (event, args) {
            if(args.name =='orderfile' || args.name == 'productfile') {
                scope.$apply(function () {
                    scope.stores.single[args.name] = args.file;
                });
                $("input[type='file']").val('');
                if(args.name == 'orderfile') {
                    scope.stores.single.type = 'order';
                } else {
                    scope.stores.single.type = 'product';
                }
                scope.update_single_store(false);
            }

        });
        $modalInstance.result.then(scope.update,scope.update);
        hotkeys.bindTo(scope).add({
            combo: 'up',
            description: 'Previous user',
            callback: myscope.up_key
        }).add({
            combo: 'down',
            description: 'Next user',
            callback: myscope.down_key
        })

    };

    myscope.init();

}]);
