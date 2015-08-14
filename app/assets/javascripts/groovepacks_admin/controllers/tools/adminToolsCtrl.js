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

    $scope.update_tenants_list = function(tenant, prop) {
        tenants.list.update_node({
            id: tenant.id,
            var: prop,
            value: tenant[prop]
        }).then(function(){myscope.get_tenants(1)});
    };

    $scope.handlesort = function(predicate) {
        myscope.common_setup_opt('sort',predicate,'tenant');
    };

    $scope.setup_child = function(childStateParams) {
        if(typeof childStateParams['type'] == 'undefined') {
            childStateParams['type'] = 'tenant';
        }
        if(typeof childStateParams['page']=='undefined' || childStateParams['page'] <= 0) {
            childStateParams['page'] = 1
        }
        myscope.get_tenants(childStateParams['page']);
    };

    $scope.delete_selected_tenants = function() {
        tenants.list.update($scope.tenants).then(function(data) {
            myscope.get_tenants();
        });
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

    myscope.open_tenant_url = function(url,event) {
        if(typeof event !='undefined') {
            event.stopPropagation();
        }
        window.open("http://"+url);
        myscope.init();
    }

    myscope.handle_click_fn = function(row,event) {
        var toState = 'tools.type.page.single';
        var toParams = {};
        for (var key in $state.params) {
            if(['filter','page'].indexOf(key) !=-1) {
                toParams[key] = $state.params[key];
            }
        }
        toParams.tenant_id = row.id;
        $scope.select_all_toggle(false);
        $state.go(toState,toParams);
    }
    
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
                    name: myscope.handle_click_fn,
                    open: myscope.open_tenant_url
                }

            },
            all_fields: {
                name: {
                    name: "Tenant",
                    editable: false,
                    transclude: '<a href="" ng-click="options.editable.functions.name(row,$event)" >{{row[field]}}</a>'
                },
                plan: {
                    name: "Plan",
                    editable: false
                },
                progress: {
                    name: "Subscription Status",
                    editable: false
                },
                transaction_errors: {
                    name: "Transaction Errors",
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
                    editable: false,
                    transclude: '<a href="" ng-click="options.editable.functions.open(row[field],$event)" >{{row[field]}}</a>'
                },
                stripe_url: {
                    name: "Stripe",
                    editable: false,
                    transclude: '<a href="" ng-click="options.editable.functions.open(\'dashboard.stripe.com/customers/\'+row[field],$event)" >Stripe URL</a>'
                }
            }
        };

        $scope.$watch('tenants.setup.search',function() {
            if($scope.tenants.setup.select_all) {
                $scope.select_all_toggle(false);
            }
            myscope.get_tenants(1);
        });
        $scope.tenant_modal_closed_callback = myscope.get_tenants;
        $scope.$watch('tenants.selected', myscope.update_selected_count,true);
    };
    
    myscope.get_tenants = function(page) {
        if(typeof page == 'undefined') {
            page = $state.params.page;
        }
        if($scope._can_load_tenants) {
            $scope._can_load_tenants = false;
            $scope.gridOptions.selections.show_delete = myscope.show_delete();
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

    myscope.common_setup_opt = function(type,value,selector) {
        tenants.setup.update($scope.tenants.setup,type,value);
        myscope.get_tenants(1);
    };
	myscope.init();
}]);
