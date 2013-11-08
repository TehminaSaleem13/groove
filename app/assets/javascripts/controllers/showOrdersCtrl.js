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

            $scope.set_defaults();
        }]);
