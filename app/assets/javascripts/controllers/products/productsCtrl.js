groovepacks_controllers.
controller('productsCtrl', [ '$scope', '$http', '$timeout', '$stateParams', '$location', '$state', '$cookies','$modal','products',
function( $scope, $http, $timeout, $stateParams, $location, $state, $cookies,$modal,products) {
    //Definitions

    var myscope= {};
    /*
     * Public methods
     */
    $scope.product_next = function(direction) {
        if(typeof direction == 'undefined' || direction !='previous') {
            return myscope.get_products();
        }
        return myscope.get_products();
    };

    $scope.select_all_toggle = function(val) {
        $scope.products.setup.select_all = val;
        for (var i =0; i < $scope.products.list.length;i++) {
            $scope.products.list[i].checked =  $scope.products.setup.select_all;
        }
    };
    $scope.update_product_list = function(product,prop) {
        products.list.update_node({
            id: product.id,
            var: prop,
            value: product[prop]
        }).then(myscope.get_products)
    };

    $scope.create_product = function () {
        $scope.products.setup.search = '';
        products.single.create($scope.products).success(function(data) {
            if(data.status) {
                myscope.handle_click_fn(data.product);
            }
        });
    };

    //Setup options
    $scope.product_setup_opt = function(type,value) {
        myscope.common_setup_opt(type,value,'product');
    };
    $scope.kit_setup_opt = function(type,value) {
        myscope.common_setup_opt(type,value,'kit');
    };

    $scope.handlesort = function(predicate) {
        myscope.common_setup_opt('sort',predicate,'product');
    };

    $scope.product_change_status = function(status) {
        $scope.products.setup.status = status;
        products.list.update('update_status',$scope.products).then(function(data) {
            $scope.products.setup.status = "";
            myscope.get_products();
        });
    };
    $scope.product_delete = function() {
        products.list.update('delete',$scope.products).then(function(data) {
            myscope.get_products();
        });
    };
    $scope.product_duplicate = function() {
        products.list.update('duplicate',$scope.products).then(function(data) {
            myscope.get_products();
        });
    };
    $scope.product_barcode = function() {
        products.list.update('barcode',$scope.products).then(function(data) {
            myscope.get_products();
        });
    };
    $scope.setup_child = function(childStateParams) {
        if(typeof childStateParams['type'] == 'undefined') {
            childStateParams['type'] = 'product';
        }
        myscope.select_tab(childStateParams['type']);
        if(typeof childStateParams['filter']!='undefined') {
            myscope.common_setup_opt('filter',childStateParams['filter'],childStateParams['type']);
        } else if(typeof childStateParams['search']!='undefined') {
            myscope.common_setup_opt('search',childStateParams['search'],childStateParams['type']);
        }
        if(typeof childStateParams['page']=='undefined' || childStateParams['page'] <= 0) {
            childStateParams['page'] = 1;
        }
        myscope.get_products(childStateParams['page']);
    };

    /*
     * Private methods
     */
    myscope.select_tab = function(type) {
        var index = (type == 'kit')? 1 : ((type == 'inventory')? 2: 0);
        for (var i = 0; i<$scope.tabs.length; i++) {
          $scope.tabs[i].open = false;
        }
        $scope.tabs[index].open = true;
    };

    myscope.load_page = function(number) {
        if($scope.products.setup.search =='') {
            var toParams = {};
            for (var key in $state.params) {
                if($state.params.hasOwnProperty(key) &&['type','filter','product_id'].indexOf(key) !=-1) {
                    toParams[key] = $state.params[key];
                }
            }
            toParams['page'] = number;
            $state.go($state.current.name,toParams);
        }
        myscope.get_products(number);
    };

    //Constructor
    myscope.init = function() {
        //Public properties
        $scope.products = products.model.get();
        $scope.tabs = [
            //accordian product tab
            {open:true},
            //accordian kit tab
            {open:false},
            //accordian inventory tab
            {open:false}
        ];

        //Private properties

        myscope.do_load_products = false;
        $scope._can_load_products = true;
        $scope.gridOptions = {
            identifier:'products',
            select_all: $scope.select_all_toggle,
            sort_func: $scope.handlesort,
            setup: $scope.products.setup,
            paginate:{
                show:true,
                //send a large number to prevent resetting page number
                total_items:50000,
                current_page:$state.params.page,
                items_per_page:$scope.products.setup.limit,
                callback: myscope.load_page
            },
            show_hide:true,
            selectable:true,
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
                    name: myscope.handle_click_fn
                }

            },
            all_fields: {
                name: {
                    name: "Item Name",
                    hideable: false,
                    transclude:'<a href="" ng-click="options.editable.functions.name(row,$event)" >{{row[field]}}</a>'
                },
                sku: {
                    name: "SKU"
                },
                status: {
                    name: "Status",
                    transclude:"<span class='label label-default' ng-class=\"{" +
                    "'label-success': row[field] == 'active', " +
                        "'label-info': row[field] == 'new' }\">" +
                        "{{row[field]}}</span>"
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
                    editable:false,
                    hidden:true
                },
                qty: {
                    name:"Avbl Inv",
                    hidden:true
                }
            }
        };

        //Register watchers
        $scope.$watch('products.setup.search',myscope.get_products);
        $scope.$watch('_can_load_products',myscope.can_do_load_products);

        $scope.$on("product-modal-closed",myscope.get_products);
        //$("#product-search-query").focus();
    };

    myscope.get_products = function(page) {
        if($scope._can_load_products) {
            $scope._can_load_products = false;
            return products.list.get($scope.products,page).success(function(response) {
                //console.log("got products");
                if($scope.products.setup.search != "") {
                    $scope.gridOptions.paginate.total_items = $scope.products.products_count['search'];
                } else {
                    $scope.gridOptions.paginate.total_items = $scope.products.products_count[$scope.products.setup['filter']];
                }
                $scope._can_load_products = true;
            })
        } else {
            myscope.do_load_products = true;
        }
    };

    myscope.common_setup_opt = function(type,value,selector) {
        products.setup.update($scope.products.setup,type,value);
        $scope.products.setup.is_kit = (selector == 'kit')? 1 : 0;
        myscope.get_products($state.params.page);
    };

    myscope.handle_click_fn = function(row,event) {
        if(typeof event !='undefined') {
            event.stopPropagation();
        }
        var toState = 'products.type.filter.page.single';
        var toParams = {};
        for (var key in $state.params) {
            if(['type','filter','page'].indexOf(key) !=-1) {
                toParams[key] = $state.params[key];
            }
        }
        toParams.product_id = row.id;

        $state.go(toState,toParams);

    };
    //Watcher ones
    myscope.can_do_load_products = function () {
        if($scope._can_load_products && myscope.do_load_products) {
            myscope.do_load_products = false;
            myscope.get_products($state.params.page);
        }
    };

    $scope.recount_or_receive_inventory = function() {
        $modal.open({
            templateUrl: '/assets/views/modals/product/inventory.html',
            controller: 'inventoryModal',
            size:'lg'
        });
    };


    //Definitions end above this line
    /*
     * Initialization
     */
    //Main code ends here. Rest is function calls etc to init
    myscope.init();
}]);
