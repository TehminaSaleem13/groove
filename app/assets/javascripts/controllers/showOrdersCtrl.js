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

    $scope.select_all_toggle = function() {
        //$scope.order_setup.select_all = !$scope.order_setup.select_all;
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
        $scope.editableOptions = {
            array:false,
            update: $scope.update_order_list,
            elements: {
                status: {
                    type:'select',
                    options:[
                        {name:"Awaiting",value:'awaiting'},
                        {name:"On Hold",value:'onhold'},
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

        };

        //Private properties
        $scope._do_load_orders = false;
        $scope._can_load_orders = true;

        $scope._all_fields = {
            tags:{name:"<i class='icon icon-ok'></i> Tags", className:"rt_field_tags"},
            store_name: {name:"<i class='icon icon-ok'></i> Store", className:"rt_field_store_name"},
            notes:{name:"<i class='icon icon-ok'></i> Notes", className:"rt_field_notes"},
            order_date:{name:"<i class='icon icon-ok'></i> Order Date", className:"rt_field_orderdate"},
            itemslength:{name:"<i class='icon icon-ok'></i> Items", className:"rt_field_itemslength"},
            recipient:{name:"<i class='icon icon-ok'></i> Recipient", className:"rt_field_recipient"},
            status:{name:"<i class='icon icon-ok'></i> Status", className:"rt_field_status"},
            email:{name:"<i class='icon icon-ok'></i> Email", className:"rt_field_email"},
            tracking_num:{name:"<i class='icon icon-ok'></i> Tracking Id", className:"rt_field_tracking_num"},
            city:{name:"<i class='icon icon-ok'></i> City", className:"rt_field_city"},
            state:{name:"<i class='icon icon-ok'></i> State", className:"rt_field_state"},
            postcode:{name:"<i class='icon icon-ok'></i> Zip", className:"rt_field_postcode"},
            country:{name:"<i class='icon icon-ok'></i> Country", className:"rt_field_country"}
        };
        $scope._shown_fields = ["checkbox","ordernum","tags","store_name","notes","orderdate","itemslength","recipient","status"];

        $.contextMenu({
            // define which elements trigger this menu
            selector: "#orderstbl thead",
            // define the elements of the menu
            items: $scope._all_fields,
            // there's more, have a look at the demos and docs...
            callback: $scope._showHideField
        });

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

        $('#orderstbl').dragtable({dragaccept:'.dragtable-sortable',clickDelay:250});
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
            $timeout($scope._checkSwapNodes,20);
            $timeout($scope._showHideField,25);
            $scope.select_all_toggle();
            if(typeof post_fn == 'function') {
                $timeout(post_fn,30);
            }
            $scope._can_load_orders = true;
        });


    }


    $scope._showHideField = function(key,options) {
        $(".context-menu-item i").removeClass("icon-ok").addClass("icon-remove");
        $("#orderstbl th, #orderstbl td").hide();
        var array_position = $scope._shown_fields.indexOf(key);
        if(array_position > -1) {
            $scope._shown_fields.splice( array_position, 1 );
        } else {
            $scope._shown_fields.push(key);
        }
        for (i in $scope._shown_fields) {
            $(".rt_field_"+$scope._shown_fields[i]+" i").removeClass("icon-remove").addClass("icon-ok");
            $("[data-header='"+$scope._shown_fields[i]+"']").show();
        }
        return false;
    }

    $scope._checkSwapNodes = function() {
        var node_order_array = [];
        $('#orderstbl thead tr').children('th').each(function(index){node_order_array[this.getAttribute('data-header')] = index;});
        $('#orderstbl tbody tr ').each(
            function(index){
                var children = this.children;
                for (i=0; i <children.length; i++) {
                    if( node_order_array[children[i].getAttribute('data-header')] != i) {
                        $scope._doRealSwap(children[i],children[node_order_array[children[i].getAttribute('data-header')]]);
                    }
                }
            }
        );
    }
    $scope._doRealSwap = function swapNodes(a, b) {
        var aparent = a.parentNode;
        var asibling = a.nextSibling === b ? a : a.nextSibling;
        b.parentNode.insertBefore(a, b);
        aparent.insertBefore(b, asibling);
    }



    $scope._init();

}]);
