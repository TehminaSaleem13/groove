groovepacks_controllers.
    controller('showOrdersCtrl', [ '$scope', '$http', '$timeout', '$routeParams', '$location', '$route', '$cookies','orders','products',
function( $scope, $http, $timeout, $routeParams, $location, $route, $cookies,orders,products) {
    //Definitions

    /*
     * Public methods
     */

    $scope.order_setup_opt = function(type,value) {
        orders.setup.update($scope.orders.setup,type,value);
        $scope._get_orders();
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
        $scope.products = products.model.get();

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
            city:{name:"<i class='icon icon-ok'></i> City", className:"rt_field_tracking_city"},
            state:{name:"<i class='icon icon-ok'></i> State", className:"rt_field_tracking_state"},
            postcode:{name:"<i class='icon icon-ok'></i> Zip", className:"rt_field_tracking_postcode"},
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
        $scope.orders_edit_tmp = {
            tags:"",
            store_name: "",
            notes:"",
            ordernum:"",
            orderdate:"",
            itemslength:"",
            recipient:"",
            status:"",
            email:"",
            tracking_num:"",
            city: "",
            state: "",
            postcode: "",
            country: "",
            editing:-1,
            editing_var: "",
            editing_id:""
        };

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












    $scope.update_order_exception = function() {
        $http.post(
            '/orders/recordexception.json',
            {
                id: $scope.single_order.basicinfo.id,
                reason: $scope.single_order.exception.reason,
                description: $scope.single_order.exception.description,
                assoc:$scope.single_order.exception.assoc
            }
        ).success(function(data) {
            if(data.status) {
                $scope.order_single_details($scope.single_order.basicinfo.id);
            } else {
                $scope.notify(data.error_messages,0);
            }
        })
    }
    $scope.clear_order_exception = function() {
        $http.post('/orders/clearexception.json', {id: $scope.single_order.basicinfo.id}).success(function(data) {
            if(data.status) {
                $scope.order_single_details($scope.single_order.basicinfo.id);
            }
        })
    }


    $scope.item_defaults = function() {
        $scope.product_setup = {};
        $scope.products = [];
        $scope.can_get_products = true;
        $scope.do_get_products = false;
        $scope.product_setup.sort = "updated_at";
        $scope.product_setup.order = "DESC";
        $scope.product_setup.filter = "all";
        $scope.product_setup.search = '';
        $scope.product_setup.select_all = false;
        $scope.product_setup.is_kit = 0;
        $scope.product_setup.limit = 20;
        $scope.product_setup.offset = 0;
        $scope.new_products = false;
    }


    $scope.item_remove_selected = function() {
        ids=[];
        for (i in $scope.single_order.items) {
            if($scope.single_order.items[i].checked ==true) {
                ids.push($scope.single_order.items[i].iteminfo.id);
            }
        }
        $http.post("orders/removeitemfromorder.json",{orderitem: ids}).success(
            function(data) {
                if(data.status) {
                    $scope.notify("Item Successfully Removed",1);
                    $scope.items_select = false;
                    $scope.order_single_details($scope.single_order.basicinfo.id);
                } else {
                    $scope.notify("Some error Occurred",0);
                }
            }
        ).error(function(data){
                $scope.notify("Some error Occurred",0);

            });

    }
    $scope.item_order = function () {
        $scope.item_defaults();
        $scope.new_products = true;
        $('#addItem').modal("show");
        $scope.get_products();
    }

    $scope.add_item_order = function(id) {
        if(confirm("Are you sure?")) {
                $http.post("orders/additemtoorder.json",{productid: id , id: $scope.single_order.basicinfo.id, qty:0}).success(
                    function(data) {
                        if(data.status) {
                            $scope.notify("Item Successfully Added",1);
                            $scope.order_single_details($scope.single_order.basicinfo.id);
                        } else {
                            $scope.notify("Some error Occurred",0);
                        }
                    }
                ).error(function(data){
                        $scope.notify("Some error Occurred",0);
                    });

        }
        $('#addItem').modal("hide");
    }
    $scope.save_item = function(){

        if($scope.item_edit.index != -1) {

            $http.post('/orders/updateiteminorder.json',{orderitem: $scope.single_order.items[$scope.item_edit.index].iteminfo.id, qty: $scope.item_edit.qty}).success(function(data) {
                if(data.status) {
                    $scope.order_single_details($scope.single_order.basicinfo.id);
                } else {
                    $scope.notify(data.messages,0);
                }
            }).error(function(data){
                $scope.notify("Some error Occurred",0);
            });
        }

    }
    $scope.edit_qty = function(index) {
        $scope.item_edit.index = index;
        if(typeof $scope.single_order.items[index].iteminfo.qty == "number" ) {
            $scope.item_edit.qty = $scope.single_order.items[index].iteminfo.qty;
        }
        $scope.single_order.items[index].iteminfo.qty = "";
        $timeout(function() {$scope.focus_input('item_qty_'+index);},500);
    }
    $scope.focus_input = function(name){
        $(".input-text [name='"+name+"']").focus();
    }
    $scope.edit_single_node = function(index,id,name) {
        $scope.save_single_node();
        $scope.orders_edit_tmp.editing_var = name;
        $scope.orders_edit_tmp.editing = index;
        $scope.orders_edit_tmp.editing_id = id;
        $scope.orders_edit_tmp[name] = $scope.orders[index][name];
        $scope.orders[index][name] = "";
        $timeout(function() {$scope.focus_input('orders_'+name+"_"+index);},10);
    }

    $scope.save_single_node = function() {
        if($scope.orders_edit_tmp.editing != -1 ) {
            $scope.orders[$scope.orders_edit_tmp.editing][$scope.orders_edit_tmp.editing_var] = $scope.orders_edit_tmp[$scope.orders_edit_tmp.editing_var];
            $scope.update_order_list(

            );
        }
        $scope.orders_edit_tmp.editing_var = "";
        $scope.orders_edit_tmp.editing = -1;
        $scope.orders_edit_tmp.editing_id = -1;
    }






}]);
