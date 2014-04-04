groovepacks_controllers.
controller('showProductsCtrl', [ '$scope', '$http', '$timeout', '$stateParams', '$location', '$state', '$cookies','products', 
    'inventory_manager', 'warehouses',
function( $scope, $http, $timeout, $stateParams, $location, $state, $cookies,products, inventory_manager, warehouses) {
    //Definitions

    /*
     * Public methods
     */
    $scope.product_next = function(post_fn) {
        $scope._get_products(true,post_fn);
    }

    $scope.select_all_toggle = function(val) {
        $scope.products.setup.select_all = val
        for (i in $scope.products.list) {
            $scope.products.list[i].checked =  $scope.products.setup.select_all;
        }
    }
    $scope.update_product_list = function(product,prop) {
        products.list.update_node({
            id: product.id,
            var: prop,
            value: product[prop]
        }).then($scope._get_products)
    }
    
    $scope.create_product = function () {
        products.single.create($scope.products).then(function(response) {
            if(response.data.status) {
                $scope.product_single_details(response.data.product.id,-1,0,true);
            }
        })
    }

    //Setup options
    $scope.product_setup_opt = function(type,value) {
        $scope._common_setup_opt(type,value,'product');
    }
    $scope.kit_setup_opt = function(type,value) {
        $scope._common_setup_opt(type,value,'kit');
    }

    $scope.handlesort = function(predicate) {
        $scope._common_setup_opt('sort',predicate,'product');
    }

    $scope.product_change_status = function(status) {
        $scope.products.setup.status = status;
        products.list.update('update_status',$scope.products).then(function(data) {
            $scope.products.setup.status = "";
            $scope._get_products();
        });
    }
    $scope.product_delete = function() {
        products.list.update('delete',$scope.products).then(function(data) {
            $scope._get_products();
        });
    }
    $scope.product_duplicate = function() {
        products.list.update('duplicate',$scope.products).then(function(data) {
            $scope._get_products();
        });
    }
    $scope.product_barcode = function() {
        products.list.update('barcode',$scope.products).then(function(data) {
            $scope._get_products();
        });
    }


    /*
     * Private methods
     */
    //Constructor
    $scope._init = function() {
        //Public properties
        $scope.products = products.model.get();

        //Private properties

        $scope._do_load_products = false;
        $scope._can_load_products = true;
        $scope.gridOptions = {
            identifier:'products',
            select_all: $scope.select_all_toggle,
            sort_func: $scope.handlesort,
            setup: $scope.products.setup,
            show_hide:true,
            draggable:true,
            sortable:true,
            editable:{
                array:false,
                update: $scope.update_product_list,
                elements: {
                    status: {
                        type:'select',
                        options:[
                            {name:"Active",value:'active'},
                            {name:"Inactive",value:'inactive'},
                            {name:"New",value:'new'}
                        ]
                    },
                    qty:{
                        type:'number',
                        min:0
                    }
                },
                functions: {
                    name: function(id,index,post_fn,open_modal) {
                        $scope.product_single_details(id,index,post_fn,open_modal);
                    }
                }

            },
            all_fields: {
                name: {
                    name: "Item Name",
                    hideable: false,
                    transclude:'<a href="" ng-click="function(ngModel.id,false,null,true)">{{ngModel.name}}</a>',
                    grid_bind: '<a href="" ng-click="options.editable.functions.name(row.id,false,null,true)" >{{row[field]}}</a>'
                },
                sku: {
                    name: "SKU"
                },
                status: {
                    name: "Status"
                },
                barcode: {
                    name:"Barcode"
                },
                location_primary: {
                    name: "Primary Location",
                    class:"span3"
                },
                store_type: {
                    name: "Store",
                    editable:false
                },
                cat:{
                    name:"Category",
                    hidden:true
                },
                location_secondary: {
                    name: "Secondary Location",
                    class:"span3",
                    hidden:true
                },
                location_name: {
                    name:"Warehouse Name",
                    class:"span3",
                    hidden:true
                },
                qty: {
                    name:"Quantity",
                    hidden:true
                }
            }
        }

        //Register watchers
        $scope.$watch('products.setup.search',$scope._search_products);
        $scope.$watch('_can_load_products',$scope._can_do_load_products);

        $scope.$on("products-modal-closed",function(event, args){event.stopPropagation(); $scope._get_products();});
        $scope.$on("products-next-load",function(event, args){$scope.product_next(function(){ $scope.$broadcast("products-next-loaded");});});
        $("#product-search-query").focus();
    }

    $scope._get_products = function(next,post_fn) {
        $scope._can_load_products = false;
        products.list.get($scope.products,next).then(function(response) {
            //console.log("got products");
            if(typeof post_fn == 'function' ) {
                //console.log("triggering post function on get products");
                $timeout(post_fn,30);
            }
            $scope.select_all_toggle(false);
            $scope._can_load_products = true;
        })

    }
    $scope._common_setup_opt = function(type,value,selector) {
        products.setup.update($scope.products.setup,type,value);
        $scope.products.setup.is_kit = (selector == 'kit')? 1 : 0;
        $scope._get_products();
    }

    //Watcher ones
    $scope._can_do_load_products = function () {
        if($scope._can_load_products) {
            if($scope._do_load_products) {
                $scope._do_load_products = false;
                //console.log("can do load triggered");
                $scope._get_products();
            }
        }
    }

    $scope._search_products = function () {
        if($scope._can_load_products) {
            $scope._get_products();
        } else {
            $scope._do_load_products = true;
        }
    }

    $scope.recount_or_receive_inventory = function() {
        //alert('Recounting or receiving inventory');
        $scope.warehouses = warehouses.model.get();
        warehouses.list.get($scope.warehouses).then(function() {
            $scope.inventory_manager = inventory_manager.model.get();
            //register events for recount and receive inventory
            $scope._inventory_warehouse_inputObj = $('input#inventorymanagerbarcode');
            $scope._inventory_warehouse_inputObj.keydown($scope._handle_inv_manager_key_event);
            $('#showProductInv').modal('show');
        });
    }

    $scope.submit_recount_or_receive_inventory = function() {
    }

    $scope._handle_inv_manager_key_event = function(event) {
        if(event.which == 13) {
            //call products service
            $scope.products = products.model.get();
            products.single.get_by_barcode($scope.inventory_manager.single.product_barcode,
                $scope.products).then(function(){
                    $scope._inventory_count_inputObj = $('input#inventory_count');
                    $scope._inventory_count_inputObj.keydown($scope._handle_inv_count_key_event);
                    $scope.inventory_manager.single.id = $scope.products.single.basicinfo.id;
                    $timeout(function() {$scope._inventory_count_inputObj.focus()},20);
                });
            //console.log($scope.inventory_manager.single.product_barcode);
        }
    }

    $scope._handle_inv_count_key_event = function() {
        if(event.which == 13) {
            //call inventory manager service
            inventory_manager.single.update($scope.inventory_manager).then(function(){
                products.single.reset_obj($scope.products);
                $('#showProductInv').modal('hide');
            });
        }
    }

    $scope.handle_change_event = function() {
        $timeout(function() {$scope._inventory_warehouse_inputObj.focus()},20);
    }

    //Definitions end above this line
    /*
     * Initialization
     */
    //Main code ends here. Rest is function calls etc to init
    $scope._init();
}]);
