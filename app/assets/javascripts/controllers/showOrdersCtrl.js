groovepacks_controllers.
    controller('showOrdersCtrl', [ '$scope', '$http', '$timeout', '$routeParams', '$location', '$route', '$cookies','orders',
function( $scope, $http, $timeout, $routeParams, $location, $route, $cookies,orders) {
    //Definitions

    /*
     * Public methods
     */

    $scope.order_setup_opt = function(type,value) {
        orders.setup.update($scope.orders.setup,type,value);
        $scope._get_orders();
    }

    $scope.handlesort = function(value) {
        $scope.order_setup_opt('sort',value);
    }

    $scope.order_next = function(post_fn) {
        $scope.orders.setup.offset = $scope.orders.setup.offset + $scope.orders.setup.limit;
        $scope._get_orders(true,post_fn);
    }

    $scope.select_all_toggle = function(val) {
        $scope.orders.setup.select_all = val;
        for (i in $scope.orders.list) {
            $scope.orders.list[i].checked =  $scope.orders.setup.select_all;
        }
    }
    $scope.update_order_list = function(order,prop) {
        orders.list.update_node({
            id: order.id,
            var:prop,
            value:order[prop]
        }).then(function(){
                $scope.orders.setup.status = "";
                $scope._get_orders();
            });

    }

    $scope.order_change_status = function(status) {
        $scope.orders.setup.status = status;
        orders.list.update('update_status',$scope.orders).then(function(data) {
            $scope.orders.setup.status = "";
            $scope._get_orders();
        });
    }
    $scope.order_delete = function() {
        orders.list.update('delete',$scope.orders).then(function(data) {
            $scope._get_orders();
        });
    }
    $scope.order_duplicate = function() {
        orders.list.update('duplicate',$scope.orders).then(function(data) {
            $scope._get_orders();
        });

    }
    /**
     * Private methods
     */
    //Constructor
    $scope._init = function() {
        //Public properties
        $scope.orders = orders.model.get();

        //Private properties
        $scope._do_load_orders = false;
        $scope._can_load_orders = true;

        $scope.gridOptions = {
            identifier:'orders',
            select_all: $scope.select_all_toggle,
            draggable:true,
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
                    ordernum: function(id,index,post_fn,open_modal) {
                        $scope.order_single_details(id,index,post_fn,open_modal);
                    }
                }

            },
            all_fields: {
                ordernum: {
                    name: "Order #",
                    hideable:false,
                    transclude:'<a href="" ng-click="function(ngModel.id,false,0,true)">{{ngModel.ordernum}}</a>',
                    grid_bind: '<a href="" ng-click="options.editable.functions.ordernum(row.id,false,null,true)" >{{row[field]}}</a>'
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
                    transclude: "<span>{{ngModel.orderdate | date:'EEEE MM/dd/yyyy hh:mm:ss a'}}</span>",
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
                    name: "Status"
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
            }



        $scope.$watch('orders.setup.search',function() {
            if($scope._can_load_orders) {
                $scope._get_orders();
            } else {
                $scope._do_load_orders = true;
            }
        });

        $scope.$watch('_can_get_orders',function() {
            if($scope._can_get_orders) {
                if($scope._do_get_orders) {
                    $scope._do_get_orders = false;
                    $scope._get_orders();
                }
            }
        });

        $scope.$on("orders-modal-closed",function(event, args){event.stopPropagation(); $scope._get_orders();});
        $scope.$on("orders-next-load",function(event, args){$scope.order_next(function(){ $scope.$broadcast("orders-next-loaded");});});
        $("#order-search-query").focus();


        $http.get('/home/userinfo.json').success(function(data){
            $scope.username = data.username;
            $scope.current_userid = data.user_id;
        });
        $('.modal-backdrop').remove();
    }

    $scope._get_orders = function(next,post_fn) {
        //$scope.loading = true;
        $scope._can_load_orders = false;
        orders.list.get($scope.orders,next).then(function(data) {
            $scope.select_all_toggle();
            if(typeof post_fn == 'function') {
                $timeout(post_fn,30);
            }
            $scope._can_load_orders = true;
        });
    }




    $scope._init();

}]);
