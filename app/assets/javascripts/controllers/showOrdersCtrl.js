groovepacks_controllers.
    controller('showOrdersCtrl', [ '$scope', '$http', '$timeout', '$routeParams', '$location', '$route', '$cookies',
        function( $scope, $http, $timeout, $routeParams, $location, $route, $q, $cookies) {
            $http.get('/home/userinfo.json').success(function(data){
                $scope.username = data.username;
            });
            $('.modal-backdrop').remove();
            $scope.get_orders = function(next) {
                next = typeof next !== 'undefined' ? next : false;
                if(!next) {
                    $scope.order_setup.limit = 10;
                    $scope.order_setup.offset = 0;
                }
                $http.get('/orders/getorders.json?filter='+$scope.order_setup.filter+'&sort='+$scope.order_setup.sort+'&order='+$scope.order_setup.order+'&limit='+$scope.order_setup.limit+'&offset='+$scope.order_setup.offset).success(function(data) {
                    if(data.status) {
                        //console.log($scope.order_setup);
                        if(!next) {
                            $scope.orders = data.orders;
                        } else {
                            for (key in data.orders) {
                                $scope.orders.push(data.orders[key]);
                            }
                        }
                        //console.log($scope.orders);
                    }
                }).error(function(data) {

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
            $scope.order_next = function() {
                $scope.order_setup.offset = $scope.order_setup.offset + $scope.order_setup.limit;
                $scope.get_orders(true);
            }
            $scope.set_defaults = function() {
                $scope.order_setup = {};
                $scope.orders = [];
                $scope.order_setup.sort = "updated_at";
                $scope.order_setup.order = "DESC";
                $scope.order_setup.filter = "awaiting";
                $scope.order_setup.select_all = false;
                $scope.order_setup.limit = 10;
                $scope.order_setup.offset = 0;
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

            $scope.order_single_details = function(id) {
                $http.get('/orders/getdetails.json?id='+id).success(function(data) {
                    console.log(data.order);
                    if(data.status) {
                        $scope.single_order = data.order;
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
                }).error(function(data) {

                    });
            }
            $scope.item_defaults = function() {
                $scope.product_setup = {};
                $scope.products = [];
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

                        $http.post("orders/additemtoorder.json",{productid: id , id: $scope.single_order.basicinfo.id}).success(
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

            $scope.set_defaults();

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
        }]);
