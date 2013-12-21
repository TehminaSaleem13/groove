groovepacks_controllers.
    controller('showOrdersCtrl', [ '$scope', '$http', '$timeout', '$routeParams', '$location', '$route', '$cookies',
function( $scope, $http, $timeout, $routeParams, $location, $route, $q, $cookies) {
    $http.get('/home/userinfo.json').success(function(data){
        $scope.username = data.username;
    });
    $('.modal-backdrop').remove();
    $scope.get_orders = function(next,post_fn) {
        //$scope.loading = true;
        $scope.can_get_orders = false;
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
        next = typeof next !== 'undefined' ? next : false;
        if(!next) {
            $scope.order_setup.limit = 10;
            $scope.order_setup.offset = 0;
        }

        if($scope.order_setup.search == "") {
            url = '/orders/getorders.json?filter='+$scope.order_setup.filter+'&sort='+$scope.order_setup.sort
                +'&order='+$scope.order_setup.order+'&limit='+$scope.order_setup.limit
                +'&offset='+$scope.order_setup.offset;
        } else {
            url = '/orders/search.json?search='+$scope.order_setup.search+'&limit='+$scope.order_setup.limit
                +'&offset='+$scope.order_setup.offset;

        }

        $http.get(url).success(function(data) {
            if(data.status) {
                //console.log($scope.order_setup);
                if(!next) {
                    $scope.orders = data.orders;
                } else {
                    for (key in data.orders) {
                        $scope.orders.push(data.orders[key]);
                    }
                }
                //console.log($scope.orders[0]);
                if(typeof post_fn == 'function') {
                    $timeout(post_fn,30);
                }
                $timeout($scope.checkSwapNodes,20);
                $timeout($scope.showHideField,25);
            }
            $scope.loading = false;
            $scope.can_get_orders = true;
        }).error(function(data) {
                $timeout($scope.checkSwapNodes,20);
                $timeout($scope.showHideField,25);
                if(typeof post_fn == 'function') {
                    $timeout(post_fn,30);
                }
                $scope.loading = true;
                $scope.can_get_orders = true;
            });
    }
    $scope.order_setup_opt = function(type,value) {
        if(type =='sort') {
            if($scope.order_setup[type] == value) {
                if($scope.order_setup.order == "DESC") {
                    $scope.order_setup.order = "ASC";
                } else {
                    $scope.order_setup.order = "DESC";
                }
            } else {
                $scope.order_setup.order = "DESC";
            }
        }
        $scope.order_setup[type] = value;
        $(".order_setup-"+type).removeClass("active");
        $(".order_setup-"+type+"-"+value).addClass("active");
        $scope.get_orders();
    }
    $scope.item_setup_opt = function (type,value) {

            if(type =='sort') {
                if($scope.product_setup[type] == value) {
                    if($scope.product_setup.order == "DESC") {
                        $scope.product_setup.order = "ASC";
                    } else {
                        $scope.product_setup.order = "DESC";
                    }
                } else {
                    $scope.product_setup.order = "DESC";
                }
            }
            $scope.product_setup[type] = value;
            $(".item_setup-"+type).removeClass("active");
            $(".item_setup-"+type+"-"+value).addClass("active");
            $scope.get_products();

    }
    $scope.order_next = function(post_fn) {
        $scope.order_setup.offset = $scope.order_setup.offset + $scope.order_setup.limit;
        $scope.get_orders(true,post_fn);
    }
    $scope.set_defaults = function() {
        $scope.order_setup = {};
        $scope.orders = [];
        $scope.currently_open = 0;
        $scope.order_setup.sort = "updated_at";
        $scope.order_setup.order = "DESC";
        $scope.order_setup.filter = "awaiting";
        $scope.order_setup.select_all = false;
        $scope.order_setup.limit = 10;
        $scope.order_setup.offset = 0;
        $scope.order_setup.search = "";
        $scope.single_order = {};

        $scope.item_defaults();
        $scope.items_select = false;
        $(".order_setup-filter-awaiting").addClass("active");
        $scope.get_orders();
    }
    $scope.select_all_toggle = function() {
        //$scope.order_setup.select_all = !$scope.order_setup.select_all;
        for (i in $scope.orders) {
            $scope.orders[i].checked =  $scope.order_setup.select_all;
        }
    }
    $scope.order_change_status = function(status) {

        $scope.order_setup.orderArray = [];

        /* get user objects of checked items */
        for( i in $scope.orders)
        {
            if ($scope.orders[i].checked == true) {
                var order = {};
                order.id = $scope.orders[i].id;
                order.status = status;
                $scope.order_setup.orderArray.push(order);
            }
        }
        /* update the server with the changed status */
        $http.put('/orders/changeorderstatus.json', $scope.order_setup).success(function(data){
            if (data.status)
            {
                $scope.order_setup.select_all = false;
                $scope.show_error = false;
            }
            else
            {
                $scope.error_msg = "There was a problem changing orders status";
                $scope.show_error = true;
            }
            $scope.get_orders();
        }).error(function(data){
                $scope.error_msg = "There was a problem changing orders status";
                $scope.show_error = true;
                $scope.get_orders();
            });
    }
    $scope.order_delete = function() {

        $scope.order_setup.orderArray = [];

        /* get user objects of checked items */
        for( i in $scope.orders)
        {
            if ($scope.orders[i].checked == true) {
                var order = {};
                order.id = $scope.orders[i].id;
                $scope.order_setup.orderArray.push(order);
            }
        }
        /* update the server with the changed status */
        $http.put('/orders/deleteorder.json', $scope.order_setup).success(function(data){
            $scope.get_orders();
            if (data.status)
            {
                $scope.show_error = false;
                $scope.order_setup.select_all = false;
                $scope.get_orders();
            }
            else
            {
                $scope.error_msg = data.message;
                $scope.show_error = true;
            }

        }).error(function(data){
                $scope.error_msg = data.message;
                $scope.show_error = true;
                $scope.get_orders();
            });
    }
    $scope.order_duplicate = function() {

        $scope.order_setup.orderArray = [];

        /* get user objects of checked items */
        for( i in $scope.orders)
        {
            if ($scope.orders[i].checked == true) {
                var order = {};
                order.id = $scope.orders[i].id;
                $scope.order_setup.orderArray.push(order);
            }
        }
        /* update the server with the changed status */
        $http.put('/orders/duplicateorder.json', $scope.order_setup).success(function(data){
            $scope.get_orders();
            if (data.status)
            {
                $scope.show_error= false;
                $scope.order_setup.select_all = false;
            }
            else
            {
                $scope.error_msg = data.message;
                $scope.show_error = true;
            }
        }).error(function(data){
                $scope.error_msg = data.message;
                $scope.show_error = true;
                $scope.get_orders();
            });
    }

    $scope.order_single_details = function(id,index) {
        if(typeof index !== 'undefined'){
            $scope.currently_open = index;
        }
        $http.get('/orders/getdetails.json?id='+id).success(function(data) {
            //console.log(data.order);
            if(data.status) {
                $scope.single_order = data.order;
                $scope.item_edit = {
                    index: -1,
                    qty: 0
                };
            }
        });


    }
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
                $scope.show_error_msgs = false;

                $scope.order_single_details($scope.single_order.basicinfo.id);
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

    $scope.product_next = function() {
        $scope.product_setup.offset = $scope.product_setup.offset + $scope.product_setup.limit;
        $scope.get_products(true);
    }
    $scope.get_products = function(next) {
        $scope.can_get_products = false;
        if(!next) {
            $scope.product_setup.offset = 0;
        }
        if($scope.product_setup.search == '') {
            url = '/products/getproducts.json?filter='+$scope.product_setup.filter+'&iskit='+$scope.product_setup.is_kit+'&sort='+$scope.product_setup.sort+'&order='+$scope.product_setup.order+'&limit='+$scope.product_setup.limit+'&offset='+$scope.product_setup.offset;
        } else {
            url = '/products/search.json?search='+$scope.product_setup.search+'&iskit='+$scope.product_setup.is_kit+'&limit='+$scope.product_setup.limit+'&offset='+$scope.product_setup.offset;
        }
        $http.get(url).success(function(data) {
            if(data.status) {
                $scope.new_products = (data.products.length > 0);
                if(!next) {
                    $scope.products = data.products;
                } else {
                    for (key in data.products) {
                        $scope.products.push(data.products[key]);
                    }
                }
            }
            $scope.can_get_products = true;
        }).error(function(data) {
                $scope.can_get_products = true;
            });
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

    $scope.item_select_all_toggle = function() {
            for (i in $scope.single_order.items) {
                $scope.single_order.items[i].checked =  $scope.items_select;
            }
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
                    $scope.show_error_msgs = false;
                    $scope.order_update_status = true;
                    $scope.order_update_message = "Item Successfully Removed";
                    $scope.items_select = false;
                    $scope.order_single_details($scope.single_order.basicinfo.id);
                } else {
                    $scope.show_error_msgs = true;
                    $scope.error_msgs = ["Some error Occurred"];
                }
            }
        ).error(function(data){
                $scope.show_error_msgs = true;
                $scope.error_msgs = ["Some error Occurred"];
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
                            $scope.show_error_msgs = false;
                            $scope.order_update_status = true;
                            $scope.order_update_message = "Item Successfully Added";
                            $scope.order_single_details($scope.single_order.basicinfo.id);
                        } else {
                            $scope.show_error_msgs = true;
                            $scope.error_msgs = ["Some error Occurred"];
                        }
                    }
                ).error(function(data){
                        $scope.show_error_msgs = true;
                        $scope.error_msgs = ["Some error Occurred"];
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
                    $scope.show_error_msgs = true;
                    $scope.error_msgs = data.messages;
                }
            }).error(function(data){
                $scope.show_error_msgs = true;
                $scope.error_msgs = ["Some error Occurred"];
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
                {
                    id: $scope.orders_edit_tmp.editing_id,
                    var:$scope.orders_edit_tmp.editing_var,
                    value: $scope.orders[$scope.orders_edit_tmp.editing][$scope.orders_edit_tmp.editing_var]
                }
            );
        }
        $scope.orders_edit_tmp.editing_var = "";
        $scope.orders_edit_tmp.editing = -1;
        $scope.orders_edit_tmp.editing_id = -1;
    }

    $scope.update_order_list = function(obj) {
        $http.post('/orders/updateorderlist.json',obj).success(function(data){
            //console.log(data);
            if(data.status) {
                $scope.show_error = false;
                $scope.show_error_msgs = false;
                $scope.get_orders();
            } else {
                $scope.show_error = true;
                $scope.error_msg = data.error_msg;
                $scope.get_orders();
            }
        }).error(function(data) {
                $scope.show_error = true;
                $scope.error_msg = "Couldn't save Order info";
                $scope.get_orders();
            });
    }

    $scope.all_fields = {
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
    $scope.shown_fields = ["checkbox","ordernum","tags","store_name","notes","orderdate","itemslength","recipient","status"];

    $scope.showHideField = function(key,options) {
        $(".context-menu-item i").removeClass("icon-ok").addClass("icon-remove");
        $("#orderstbl th, #orderstbl td").hide();
        var array_position = $scope.shown_fields.indexOf(key);
        if(array_position > -1) {
            $scope.shown_fields.splice( array_position, 1 );
        } else {
            $scope.shown_fields.push(key);
        }
        for (i in $scope.shown_fields) {
            $(".rt_field_"+$scope.shown_fields[i]+" i").removeClass("icon-remove").addClass("icon-ok");
            $("[data-header='"+$scope.shown_fields[i]+"']").show();
        }
    }

    $.contextMenu({
        // define which elements trigger this menu
        selector: "#orderstbl thead",
        // define the elements of the menu
        items: $scope.all_fields,
        // there's more, have a look at the demos and docs...
        callback: $scope.showHideField
    });
    $scope.update_single_order = function() {
        order_data = {};
        for(i in $scope.single_order.basicinfo) {
            if(i != 'id' && i != 'created_at' && i!='updated_at') {
                order_data[i] = $scope.single_order.basicinfo[i];
            }
        }
        $http.post("orders/update.json",{id: $scope.single_order.basicinfo.id , order: order_data}).success(
            function(data) {
                $scope.show_error_msgs = false;
                $scope.order_update_status = true;
                $scope.order_update_message = "Order Updated";
                $scope.order_single_details($scope.single_order.basicinfo.id);
            }
        ).error(function(data){
                $scope.show_error_msgs = true;
                $scope.error_msgs = ["Some error Occurred"];
        });
    }

    $scope.keyboard_nav_event = function(event) {
        if($('#showOrder').hasClass("in") &&  !$('#addItem').hasClass("in")) {
            if(event.which == 38) {//up key
                if($scope.currently_open > 0) {
                    $scope.order_single_details($scope.orders[$scope.currently_open -1].id, $scope.currently_open - 1);
                } else {
                    alert("Already at the top of the list");
                }
            } else if(event.which == 40) { //down key
                if($scope.currently_open < $scope.orders.length -1) {
                    $scope.order_single_details($scope.orders[$scope.currently_open + 1].id, $scope.currently_open + 1);
                } else {
                    $scope.order_next(
                        function() {
                            if($scope.currently_open < $scope.orders.length -1) {
                                $scope.order_single_details($scope.orders[$scope.currently_open + 1].id, $scope.currently_open + 1);
                            } else {
                                alert("Already at the bottom of the list");
                            }
                        }
                    );
                }
            } else if(event.which == 39 || event.which == 37){
                //Horizontal movement
                var mytab = $("#myTab li");
                var count = mytab.length;
                var active_index = $("#myTab li.active").index();
                var next_index = 1;
                var prev_index = count;

                if(event.which == 39) { //right key
                    if(active_index+1 < count) {
                        next_index = active_index+2;
                    }
                    $("#myTab li:nth-child("+next_index+") a").click();
                } else if(event.which == 37) { //left key

                    if(active_index > 0) {
                        prev_index = active_index;
                    }
                    $("#myTab li:nth-child("+prev_index+") a").click();
                }
            }

        }
    }

    $scope.checkSwapNodes = function() {
        var node_order_array = [];
        $('#orderstbl thead tr').children('th').each(function(index){node_order_array[this.getAttribute('data-header')] = index;});
        $('#orderstbl tbody tr ').each(
            function(index){
                var children = this.children;
                for (i=0; i <children.length; i++) {
                    if( node_order_array[children[i].getAttribute('data-header')] != i) {
                        $scope.doRealSwap(children[i],children[node_order_array[children[i].getAttribute('data-header')]]);
                    }
                }
            }
        );
    }
    $scope.doRealSwap = function swapNodes(a, b) {
        var aparent = a.parentNode;
        var asibling = a.nextSibling === b ? a : a.nextSibling;
        b.parentNode.insertBefore(a, b);
        aparent.insertBefore(b, asibling);
    }

    $scope.set_defaults();
    $('#orderstbl').dragtable({dragaccept:'.order_setup-sort',clickDelay:250});
    $scope.$watch('product_setup.search',function() {
        if($scope.can_get_products) {
            $scope.get_products();
        } else {
            $scope.do_get_products = true;
        }
    });
    $scope.$watch('order_setup.search',function() {
        if($scope.can_get_orders) {
            $scope.get_orders();
        } else {
            $scope.do_get_orders = true;
        }
    });

    $scope.$watch('can_get_products',function() {
        if($scope.can_get_products) {
            if($scope.do_get_products) {
                $scope.do_get_products = false;
                $scope.get_products();
            }
        }
    });
    $scope.$watch('can_get_orders',function() {
        if($scope.can_get_orders) {
            if($scope.do_get_orders) {
                $scope.do_get_orders = false;
                $scope.get_orders();
            }
        }
    });
    $('#showOrder').keydown($scope.keyboard_nav_event);
    $scope.$watch('order_update_status',function() {
        if($scope.order_update_status) {
            $("#order_update_status").fadeTo("fast",1,function() {
                $("#order_update_status").fadeTo("slow", 0 ,function() {
                    $scope.order_update_status = false;
                });
            });
        }
    });
    $('.regular-input').focusout($scope.update_single_order);
    $("#order-search-query").focus();
}]);
