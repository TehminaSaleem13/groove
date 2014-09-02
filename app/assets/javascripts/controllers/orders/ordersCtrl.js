groovepacks_controllers.
    controller('ordersCtrl', [ '$scope', '$http', '$timeout', '$stateParams', '$location', '$state', '$cookies','$q','orders','$modal',
function( $scope, $http, $timeout, $stateParams, $location, $state, $cookies,$q,orders,$modal) {
    //Definitions

    var myscope = {};
    /*
     * Public methods
     */


    $scope.handlesort = function(value) {
        myscope.order_setup_opt('sort',value);
    };

    $scope.load_page = function(direction) {
        var page = parseInt($state.params.page,10);
        page = (typeof direction == 'undefined' || direction !='previous')? page+1 : page-1;
        return myscope.load_page_number(page);
    };

    $scope.select_all_toggle = function(val) {
        $scope.orders.setup.select_all = val;
        $scope.orders.selected = [];
        for (var i =0; i< $scope.orders.list.length; i++) {
            $scope.orders.list[i].checked =  $scope.orders.setup.select_all;
        }
    };
    $scope.update_order_list = function(order,prop) {
        orders.list.update_node({
            id: order.id,
            var:prop,
            value:order[prop]
        }).then(function(){
                $scope.orders.setup.status = "";
                myscope.get_orders();
        });

    };

    $scope.order_change_status = function(status) {
        $scope.orders.setup.status = status;
        orders.list.update('update_status',$scope.orders).then(function(data) {
            $scope.orders.setup.status = "";
            myscope.get_orders();
        });
    };
    $scope.order_delete = function() {
        orders.list.update('delete',$scope.orders).then(function(data) {
            myscope.get_orders();
        });
    };
    $scope.order_duplicate = function() {
        orders.list.update('duplicate',$scope.orders).then(function(data) {
            myscope.get_orders();
        });

    };
    $scope.generate_orders_pick_list = function() {
        orders.list.generate('pick_list',$scope.orders).then(
            function(data){});
    };
    $scope.generate_orders_packing_slip = function() {
        orders.list.generate('packing_slip',$scope.orders).then(
            function(data){});
    };
    $scope.generate_orders_pick_list_and_packing_slip = function() {
        //call the pick_list and packing_slip actions separately, to get the pdfs.
        orders.list.generate('pick_list',$scope.orders).then(
            function(data){});
        orders.list.generate('packing_slip',$scope.orders).then(
            function(data){});
    };

    $scope.setup_child = function(childStateParams) {
        if(typeof childStateParams['filter']!='undefined') {
            orders.setup.update($scope.orders.setup,'filter',childStateParams['filter']);
        } else if(typeof childStateParams['search']!='undefined') {
            orders.setup.update($scope.orders.setup,'search',childStateParams['search']);
        }
        if(typeof childStateParams['page']=='undefined' || childStateParams['page'] <= 0) {
            childStateParams['page'] = 1
        }
        myscope.get_orders(childStateParams['page']);
    };

    /**
     * Private methods
     */
    //Constructor
    myscope.handle_click_fn = function(row,event) {
        if(typeof event !='undefined') {
            event.stopPropagation();
        }
        if(event.ctrlKey || event.metaKey) {
            $state.go("scanpack.rfp.default",{order_num: row.ordernum});
        } else {
            var toState = 'orders.filter.page.single';
            var toParams = {};
            for (var key in $state.params) {
                if(['filter','page'].indexOf(key) !=-1) {
                    toParams[key] = $state.params[key];
                }
            }
            toParams.order_id = row.id;
            $scope.select_all_toggle(false);
            $state.go(toState,toParams);
        }
    };

    myscope.select_single = function(row) {
        orders.single.select($scope.orders,row);
    };

    myscope.load_page_number = function(page) {
        if(page > 0 && page <= Math.ceil($scope.gridOptions.paginate.total_items/$scope.gridOptions.paginate.items_per_page)) {
            if($scope.orders.setup.search =='') {
                var toParams = {};
                for (var key in $state.params) {
                    if($state.params.hasOwnProperty(key) &&['filter','order_id'].indexOf(key) !=-1) {
                        toParams[key] = $state.params[key];
                    }
                }
                toParams['page'] = page;
                $state.go($state.current.name,toParams);
            }
            return myscope.get_orders(page);
        } else {
            var req = $q.defer();
            req.reject();
            return req.promise;
        }
    };

    myscope.order_setup_opt = function(type,value) {
        orders.setup.update($scope.orders.setup,type,value);
        myscope.get_orders();
    };

    myscope.get_orders = function(page) {
        if(typeof page == 'undefined') {
            page = $state.params.page;
        }
        if($scope._can_load_orders) {
            $scope._can_load_orders = false;
            return orders.list.get($scope.orders,page).then(function(data) {
                $scope.gridOptions.paginate.total_items = orders.list.total_items($scope.orders);
                $scope._can_load_orders = true;
            });
        } else {
            myscope.do_load_orders = true;
            var req= $q.defer();
            req.resolve();
            return req.promise;
        }

    };

    myscope.init = function() {
        //Public properties
        $scope.orders = orders.model.get();
        $scope.firstOpen = true;

        //Private properties
        myscope.do_load_orders = false;
        $scope._can_load_orders = true;

        $scope.gridOptions = {
            identifier:'orders',
            select_all: $scope.select_all_toggle,
            select_single: myscope.select_single,
            draggable:true,
            sortable:true,
            selectable:true,
            sort_func: $scope.handlesort,
            setup: $scope.orders.setup,
            show_hide:true,
            paginate:{
                show:true,
                //send a large number to prevent resetting page number
                total_items:50000,
                current_page:$state.params.page,
                items_per_page:$scope.orders.setup.limit,
                callback: myscope.load_page_number
            },
            editable:{
                array:false,
                update: $scope.update_order_list,
                elements: {
                    status: {
                        type:'select',
                        options:[
                            {name:"Awaiting",value:'awaiting'},
                            {name:"On Hold",value:'onhold'},
                            {name:"Service Issue",value:'serviceissue'},
                            {name:"Cancelled",value:'cancelled'},
                            {name:"Scanned",value:'scanned'}
                        ]
                    }
                },
                functions: {
                    ordernum: myscope.handle_click_fn
                }

            },
            all_fields: {
                ordernum: {
                    name: "Order #",
                    hideable:false,
                    editable: false,
                    //transclude:'<a href="" ng-click="function(ngModel.id,false,0,true)">{{ngModel.ordernum}}</a>',
                    transclude: '<a href="" ng-click="options.editable.functions.ordernum(row,$event)" >{{row[field]}}</a>'
                },
                //tags: {
                //    name:"Tags",
                //    editable:false,
                //    sortable:false,
                //    transclude: '<div style="width:80px;">'+
                //        '<ul class="inline tag-list">'+
                //        '<li ng-repeat = "tag in row[field]">'+
                //        '<div class="tag-top-bottom-box" ng-show="tag.mark_place == 1"></div>'+
                //        '<div class="tagbox" ng-style="{background: tag.color}"></div>'+
                //        '<div class="tag-top-bottom-box" ng-show="tag.mark_place == 0"></div>'+
                //        '</li></ul></div>'
                //},
                store_name: {
                    name:"Store",
                    editable:false
                },
                notes:{
                    name:"Notes"
                },
                order_date:{
                    name:"Order Date",
                    transclude:"<span>{{row[field] | date:'EEEE MM/dd/yyyy hh:mm:ss a'}}</span>"
                },
                itemslength:{
                    name:"Items",
                    editable:false
                },
                recipient: {
                    name:"Recipient"
                },
                status: {
                    name: "Status",
                    transclude:"<span class='label label-default' ng-class=\"{" +
                        "'label-success': row[field] == 'awaiting', " +
                        "'label-warning': row[field] == 'onhold', " +
                        "'label-danger': row[field] == 'serviceissue' }\">" +
                        "{{row[field]}}</span>"
                },
                email:{
                    name: "Email",
                    hidden:true
                },
                tracking_num: {
                    name: "Tracking Id",
                    hidden:true
                },
                city: {
                    name: "City",
                    hidden:true
                },
                state:{
                    name:"State",
                    hidden:true
                },
                postcode:{
                    name:"Zip",
                    hidden:true
                },
                country: {
                    name:"Country",
                    hidden:true
                }
            }
        };



        $scope.$watch('orders.setup.search',function(){
            $scope.select_all_toggle(false);
            myscope.load_page_number(1);
        });

        $scope.$watch('_can_load_orders',function() {
            if($scope._can_load_orders) {
                if(myscope.do_load_orders) {
                    myscope.do_load_orders = false;
                    myscope.get_orders();
                }
            }
        });

        $scope.$on("order-modal-closed",myscope.get_orders);

    };





    myscope.init();

}]);
