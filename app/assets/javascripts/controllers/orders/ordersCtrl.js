groovepacks_controllers.
    controller('ordersCtrl', [ '$scope', '$http', '$timeout', '$stateParams', '$location', '$state', '$cookies','orders','$modal',
function( $scope, $http, $timeout, $stateParams, $location, $state, $cookies,orders,$modal) {
    //Definitions

    var myscope = {};
    /*
     * Public methods
     */


    $scope.handlesort = function(value) {
        myscope.order_setup_opt('sort',value);
    };

    $scope.order_next = function(post_fn) {
        $scope.orders.setup.offset = $scope.orders.setup.offset + $scope.orders.setup.limit;
        myscope.get_orders(true,post_fn);
    };

    $scope.select_all_toggle = function(val) {
        $scope.orders.setup.select_all = val;
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
        if(typeof childStateParams['page']!='undefined') {
            //Implement pagination after porting finishes
        }
        myscope.get_orders();
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
            if(typeof $state.params['search'] != 'undefined') {
                toState = 'orders.search.page.single';
            }
            var toParams = {};
            for (var key in $state.params) {
                if(['filter','search','page'].indexOf(key) !=-1) {
                    toParams[key] = $state.params[key];
                }
            }
            toParams.order_id = row.id;

            $state.go(toState,toParams);
        }
    };

    myscope.order_setup_opt = function(type,value) {
        orders.setup.update($scope.orders.setup,type,value);
        myscope.get_orders();
    };

    myscope.get_orders = function(next,post_fn) {
        //$scope.loading = true;
        $scope._can_load_orders = false;
        orders.list.get($scope.orders,next).then(function(data) {
            $scope.select_all_toggle();
            if(typeof post_fn == 'function') {
                $timeout(post_fn,30);
            }
            $scope._can_load_orders = true;
        });
    };

    myscope.init = function() {
        //Public properties
        $scope.orders = orders.model.get();
        $scope.firstOpen = true;

        //Private properties
        $scope._do_load_orders = false;
        $scope._can_load_orders = true;

        $scope.gridOptions = {
            identifier:'orders',
            select_all: $scope.select_all_toggle,
            draggable:true,
            sortable:true,
            selectable:true,
            sort_func: $scope.handlesort,
            setup: $scope.orders.setup,
            show_hide:true,
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
                    grid_bind: '<a href="" ng-click="options.editable.functions.ordernum(row,$event)" >{{row[field]}}</a>'
                },
                tags: {
                    name:"Tags",
                    editable:false,
                    sortable:false,
                    grid_bind: '<div style="width:80px;">'+
                        '<ul class="inline tag-list">'+
                        '<li ng-repeat = "tag in row[field]">'+
                        '<div class="tag-top-bottom-box" ng-show="tag.mark_place == 1"></div>'+
                        '<div class="tagbox" ng-style="{background: tag.color}"></div>'+
                        '<div class="tag-top-bottom-box" ng-show="tag.mark_place == 0"></div>'+
                        '</li></ul></div>'
                },
                store_name: {
                    name:"Store",
                    editable:false
                },
                notes:{
                    name:"Notes"
                },
                order_date:{
                    name:"Order Date",
                    transclude:"<span>{{row[field] | date:'EEEE MM/dd/yyyy hh:mm:ss a'}}</span>",
                    grid_bind: "<span>{{row[field] | date:'EEEE MM/dd/yyyy hh:mm:ss a'}}</span>"
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
                        "{{row[field]}}</span>",
                    grid_bind:"<span class='label label-default' ng-class=\"{" +
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



        $scope.$watch('orders.setup.search',function() {
            if($scope._can_load_orders) {
                myscope.get_orders();
            } else {
                $scope._do_load_orders = true;
            }
        });

        $scope.$watch('_can_load_orders',function() {
            if($scope._can_load_orders) {
                if($scope._do_load_orders) {
                    $scope._do_load_orders = false;
                    myscope.get_orders();
                }
            }
        });

        $scope.$on("order-modal-closed",myscope.get_orders);

    };





    myscope.init();

}]);
