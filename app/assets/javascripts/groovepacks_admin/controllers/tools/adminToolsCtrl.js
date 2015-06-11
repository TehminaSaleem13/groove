groovepacks_admin_controllers. 
controller('adminToolsCtrl', [ '$scope', '$http', '$timeout', '$location', '$state', '$cookies','tenants',
function( $scope, $http, $timeout, $location, $state, $cookies, tenants) {

    var myscope= {};
    
    $scope.load_page = function(direction) {
        var page = parseInt($state.params.page,10);
        page = (typeof direction == 'undefined' || direction !='previous')? page+1 : page-1;
        return myscope.load_page_number(page);
    };

    $scope.select_all_toggle = function(val) {
        $scope.products.setup.select_all = !!val;
        myscope.invert(false);
        $scope.products.selected = [];
        for (var i =0; i < $scope.products.list.length;i++) {
            $scope.products.list[i].checked =  $scope.products.setup.select_all;
            if($scope.products.setup.select_all) {
                myscope.select_single($scope.products.list[i]);
            }
        }
    };

    $scope.update_product_list = function(product, prop) {
        products.list.update_node({
            id: product.id,
            var: prop,
            value: product[prop]
        }).then(function(){myscope.get_products()});
    };

    $scope.create_product = function () {
        $scope.products.setup.search = '';
        products.single.create($scope.products).success(function(data) {
            if(data.status) {
                $state.params.filter = 'new';
                data.product.new_product = true;
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
        if (confirm('All orders with these product(s) will be put On Hold. Are you sure you want to delete the selected product(s)?')) {
            products.list.update('delete',$scope.products).then(function(data) {
                myscope.get_products();
            });
        }
    };

    $scope.product_receiving_label = function() {
        products.list.update('receiving_label',$scope.products).then(function(data) {
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
        if($scope.products.setup.select_all) {
            $scope.select_all_toggle(false);
        }
        return myscope.get_products(childStateParams['page']);
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

    myscope.select_single = function(row) {
        products.single.select($scope.products,row);
    };

    myscope.select_pages = function(from,to,state) {
        products.list.select($scope.products,from,to,state);
    };

    myscope.invert = function(val) {
        $scope.products.setup.inverted = !!val;

        if($scope.products.setup.inverted) {
            if($scope.products.setup.select_all) {
                $scope.select_all_toggle(false);
            } else if($scope.products.selected.length == 0) {
                $scope.select_all_toggle(true);
            }
        }
        myscope.update_selected_count();
    };

    myscope.load_page_number = function(page) {
        if(page > 0 && page <= Math.ceil($scope.gridOptions.paginate.total_items/$scope.gridOptions.paginate.items_per_page)) {
            if($scope.products.setup.search =='') {
                var toParams = {};
                for (var key in $state.params) {
                    if($state.params.hasOwnProperty(key) &&['type','filter','product_id'].indexOf(key) !=-1) {
                        toParams[key] = $state.params[key];
                    }
                }
                toParams['page'] = page;
                $state.go($state.current.name,toParams);
            }
            return myscope.get_products(page);
        } else {
            var req = $q.defer();
            req.reject();
            return req.promise;
        }
    };

    myscope.show_delete = function() {
        if ($state.params.filter == 'inactive') {
            return true;
        }
        return false;
    };


    myscope.init = function() {
        $scope.tenants = tenants.model.get();
        $scope.current_page = "show_admin_tools";
        $scope.tabs = [
                    {
                        page:'show_admin_tools',
                        open:true
                    }
                ];
        myscope.do_load_tenants = false;
        $scope._can_load_tenants = true;
        $scope.gridOptions = {
            identifier: 'tenants',
            select_all: $scope.select_all_toggle,
            invert: myscope.invert,
            sort_func: $scope.handlesort,
            setup: $scope.tenants.setup,
            selections: {
                show_dropdown: true,
                single_callback: myscope.select_single,
                multi_page: myscope.select_pages,
                selected_count: 0,
                show: myscope.show_selected,
                show_delete: myscope.show_delete()
            },
            paginate:{
                show: true,
                //send a large number to prevent resetting page number
                total_items: 50000,
                current_page: $state.params.page,
                // items_per_page: $scope.products.setup.limit,
                callback: myscope.load_page_number
            },
            show_hide: true,
            selectable: true,
            draggable: true,
            sortable: true,
            editable:{
                array: false,
                update: $scope.update_tenants_list,
                elements: {
                    
                },
                functions: {
                    name: myscope.handle_click_fn
                }

            },
            all_fields: {
                name: {
                    name: "Name",
                    editable: false
                },
                online: {
                    name: "Online"
                },
                active: {
                    name: "Active"
                }
            }
        };
        $scope.$watch('tenants.setup.search',function() {
            if($scope.tenants.setup.select_all) {
                $scope.select_all_toggle(false);
            }
            myscope.get_tenants();
        });
    };
    myscope.get_tenants = function() {
        console.log("get_tenatns");
        $scope.gridOptions.selections.show_delete = myscope.show_delete();
        return tenants.list.get($scope.tenants).success(function(response) {
            console.log("response:"+response);
            $scope.gridOptions.paginate.total_items = tenants.list.total_items($scope.tenants);
            // myscope.update_selected_count();
        }).error(function(){
        });
    };
	myscope.init();
}]);
