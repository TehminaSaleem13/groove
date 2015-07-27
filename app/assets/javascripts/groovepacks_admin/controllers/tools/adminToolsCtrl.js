groovepacks_admin_controllers. 
controller('adminToolsCtrl', [ '$scope', '$http', '$timeout', '$location', '$state', '$cookies', '$q','tenants',
function( $scope, $http, $timeout, $location, $state, $cookies, $q, tenants) {

    var myscope= {};
    
    $scope.load_page = function(direction) {
        var page = parseInt($state.params.page,10);
        page = (typeof direction == 'undefined' || direction !='previous')? page+1 : page-1;
        return myscope.load_page_number(page);
    };

    $scope.select_all_toggle = function(val) {
        $scope.tenants.setup.select_all = !!val;
        myscope.invert(false);
        $scope.tenants.selected = [];
        for (var i =0; i < $scope.tenants.list.length;i++) {
            $scope.tenants.list[i].checked =  $scope.tenants.setup.select_all;
            if($scope.tenants.setup.select_all) {
                myscope.select_single($scope.tenants.list[i]);
            }
        }
    };

    $scope.update_product_list = function(product, prop) {
        tenants.list.update_node({
            id: product.id,
            var: prop,
            value: product[prop]
        }).then(function(){myscope.get_tenants()});
    };

    $scope.create_product = function () {
        $scope.tenants.setup.search = '';
        tenants.single.create($scope.tenants).success(function(data) {
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
        $scope.tenants.setup.status = status;
        tenants.list.update('update_status',$scope.tenants).then(function(data) {
            $scope.tenants.setup.status = "";
            myscope.get_tenants();
        });
    };

    $scope.product_delete = function() {
        if (confirm('All orders with these product(s) will be put On Hold. Are you sure you want to delete the selected product(s)?')) {
            tenants.list.update('delete',$scope.tenants).then(function(data) {
                myscope.get_tenants();
            });
        }
    };

    $scope.product_receiving_label = function() {
        tenants.list.update('receiving_label',$scope.tenants).then(function(data) {
            myscope.get_tenants();
        });
    };

    $scope.product_duplicate = function() {
        tenants.list.update('duplicate',$scope.tenants).then(function(data) {
            myscope.get_tenants();
        });
    };

    $scope.product_barcode = function() {
        tenants.list.update('barcode',$scope.tenants).then(function(data) {
            myscope.get_tenants();
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
        if($scope.tenants.setup.select_all) {
            $scope.select_all_toggle(false);
        }
        return myscope.get_tenants(childStateParams['page']);
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

    myscope.update_selected_count = function() {
        if($scope.tenants.setup.inverted && $scope.gridOptions.paginate.show) {
            $scope.gridOptions.selections.selected_count = $scope.gridOptions.paginate.total_items - $scope.tenants.selected.length;
        } else {
            $scope.gridOptions.selections.selected_count = $scope.tenants.selected.length;
        }
    };

    myscope.select_single = function(row) {
        tenants.single.select($scope.tenants,row);
    };

    myscope.select_pages = function(from,to,state) {
        tenants.list.select($scope.tenants,from,to,state);
    };

    myscope.invert = function(val) {
        $scope.tenants.setup.inverted = !!val;

        if($scope.tenants.setup.inverted) {
            if($scope.tenants.setup.select_all) {
                $scope.select_all_toggle(false);
            } else if($scope.tenants.selected.length == 0) {
                $scope.select_all_toggle(true);
            }
        }
        myscope.update_selected_count();
    };

    myscope.load_page_number = function(page) {

        if(page > 0 && page <= Math.ceil($scope.gridOptions.paginate.tenants_count/$scope.gridOptions.paginate.items_per_page)) {
            if($scope.tenants.setup.search =='') {
                var toParams = {};
                for (var key in $state.params) {
                    if($state.params.hasOwnProperty(key) &&['type','filter','tenant_id'].indexOf(key) !=-1) {
                        toParams[key] = $state.params[key];
                    }
                }
                toParams['page'] = page;
                $state.go($state.current.name,toParams);
            }
            return myscope.get_tenants(page);
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
        myscope.do_load_tentants = false;
        $scope._can_load_tentants = true;
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
            list: $scope.tenants.list,
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
                tenants_count: 50000,
                current_page: $state.params.page,
                items_per_page: $scope.tenants.setup.limit,
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
                    name: "Tenant",
                    editable: false
                },
                plan: {
                    name: "Plan",
                    editable: false
                },
                shipped_last: {
                    name: "Shipped Last Month",
                    editable: false
                },
                total_shipped: {
                    name: "Shipped This Month",
                    editable: false
                },
                max_allowed: {
                    name: "Plan Max",
                    editable: false
                },
                last_activity: {
                    name: "Last Activity",
                    editable: false
                },
                is_importing: {
                    name: "Import Running",
                    editable: false
                },
                cpu: {
                    name: "CPU",
                    editable: false
                },
                memory: {
                    name: "Memory",
                    editable: false
                },
                import_log: {
                    name: "Import Log Log",
                    editable: false
                },
                url: {
                    name: "URL",
                    editable: false
                },
                stripe_url: {
                    name: "Stripe",
                    editable: false
                }
            }
        };
        $scope.$watch('tenants.setup.search',function() {
            if($scope.tenants.setup.select_all) {
                $scope.select_all_toggle(false);
            }
            myscope.get_tenants(1);
        });
    };
    // myscope.get_tenants = function(page) {
    //     console.log("get_tenants");
    //     $scope.gridOptions.selections.show_delete = myscope.show_delete();
    //     return tenants.list.get($scope.tenants,page).success(function(response) {
    //         console.log("response:"+response);
    //         // tenants.list.get($scope.tenants,page);
    //         $scope.gridOptions.list = $scope.tenants.list;
    //         $scope.gridOptions.paginate.tenants_count = $scope.tenants.tenants_count;
    //         console.log($scope.gridOptions.paginate.tenants_count);
    //         myscope.update_selected_count();
    //     }).error(function(){
    //     });
    // };

    myscope.get_tenants = function(page) {
        if(typeof page == 'undefined') {
            page = $state.params.page;
        }
        if($scope._can_load_tenants) {
            $scope._can_load_tenants = false;
            return tenants.list.get($scope.tenants,page).success(function(data) {
                $scope.gridOptions.paginate.tenants_count = tenants.list.total_tenants($scope.tenants);
                myscope.update_selected_count();
                $scope._can_load_tenants = true;
            }).error(function(){
                $scope._can_load_tenants = true;
            });
        } else {
            myscope.do_load_tentants = page;
            var req= $q.defer();
            req.resolve();
            return req.promise;
        }

    };
	myscope.init();
}]);
