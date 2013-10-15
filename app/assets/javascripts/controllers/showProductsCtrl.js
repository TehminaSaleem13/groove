groovepacks_controllers.
controller('showProductsCtrl', [ '$scope', '$http', '$timeout', '$routeParams', '$location', '$route', '$cookies',
    function( $scope, $http, $timeout, $routeParams, $location, $route, $q, $cookies) {
    	$http.get('/home/userinfo.json').success(function(data){
    		$scope.username = data.username;
    	});
        $('.modal-backdrop').remove();
    	$scope.get_products = function(next) {
            next = typeof next !== 'undefined' ? next : false;
            if(!next) {
                $scope.product_setup.limit = 10;
                $scope.product_setup.offset = 0;
            }
            if($scope.product_setup.search == '') {
                url = '/products/getproducts.json?filter='+$scope.product_setup.filter+'&sort='+$scope.product_setup.sort+'&order='+$scope.product_setup.order+'&limit='+$scope.product_setup.limit+'&offset='+$scope.product_setup.offset;
            } else {
                url = '/products/search.json?search='+$scope.product_setup.search+'&limit='+$scope.product_setup.limit+'&offset='+$scope.product_setup.offset;
            }
            $http.get(url).success(function(data) {
                if(data.status) {
                    console.log($scope.product_setup);
                    if(!next) {
                        $scope.products = data.products;
                    } else {
                        for (key in data.products) {
                            $scope.products.push(data.products[key]);
                        }
                    }
                    console.log($scope.products);
                }
            }).error(function(data) {

            });
        }
        $scope.product_setup_opt = function(type,value) {
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
            $(".product_setup-"+type).removeClass("active");
            $(".product_setup-"+type+"-"+value).addClass("active");
            $scope.get_products();
        }
        $scope.product_next = function() {
            $scope.product_setup.offset = $scope.product_setup.offset + $scope.product_setup.limit;
            $scope.get_products(true);
        }
        $scope.set_defaults = function() {
            $scope.product_setup = {};
            $scope.products = [];
            $scope.product_setup.sort = "updated_at";
            $scope.product_setup.order = "DESC";
            $scope.product_setup.filter = "active";
            $scope.product_setup.search = '';
            $scope.product_setup.select_all = false;
            $scope.product_setup.limit = 10;
            $scope.product_setup.offset = 0;
            $(".product_setup-filter-active").addClass("active");
            $scope.get_products();
        }
        $scope.select_all_toggle = function() {
            //$scope.product_setup.select_all = !$scope.product_setup.select_all;
            for (i in $scope.products) {
                $scope.products[i].checked =  $scope.product_setup.select_all;
            }
        }
        $scope.product_change_status = function(status) {

            $scope.product_setup.productArray = [];

            /* get user objects of checked items */
            for( i in $scope.products)
            {
                if ($scope.products[i].checked == true) {
                    var product = {};
                    product.id = $scope.products[i].id;
                    product.status = status;
                    $scope.product_setup.productArray.push(product);
                }
            }
            /* update the server with the changed status */
            $http.put('/products/changeproductstatus.json', $scope.product_setup).success(function(data){
                if (data.status)
                {
                    $scope.product_setup.select_all = false;

                }
                else
                {
                    $scope.error_msg = "There was a problem changing products status";
                    $scope.show_error = true;
                }
                $scope.get_products();
            }).error(function(data){
                    $scope.error_msg = "There was a problem changing products status";
                    $scope.show_error = true;
                    $scope.get_products();
                });
        }
        $scope.product_delete = function() {

            $scope.product_setup.productArray = [];

            /* get user objects of checked items */
            for( i in $scope.products)
            {
                if ($scope.products[i].checked == true) {
                    var product = {};
                    product.id = $scope.products[i].id;
                    $scope.product_setup.productArray.push(product);
                }
            }
            /* update the server with the changed status */
            $http.put('/products/deleteproduct.json', $scope.product_setup).success(function(data){
                $scope.get_products();
                if (data.status)
                {
                    $scope.product_setup.select_all = false;
                    $scope.get_products();
                }
                else
                {
                    $scope.error_msg = data.message;
                    $scope.show_error = true;
                }

            }).error(function(data){
                    $scope.error_msg = data.message;
                    $scope.show_error = true;
                    $scope.get_products();
                });
        }
        $scope.product_duplicate = function() {

            $scope.product_setup.productArray = [];

            /* get user objects of checked items */
            for( i in $scope.products)
            {
                if ($scope.products[i].checked == true) {
                    var product = {};
                    product.id = $scope.products[i].id;
                    $scope.product_setup.productArray.push(product);
                }
            }
            /* update the server with the changed status */
            $http.put('/products/duplicateproduct.json', $scope.product_setup).success(function(data){
                $scope.get_products();
                if (data.status)
                {
                    $scope.product_setup.select_all = false;
                }
                else
                {
                    $scope.error_msg = data.message;
                    $scope.show_error = true;
                }
            }).error(function(data){
                    $scope.error_msg = data.message;
                    $scope.show_error = true;
                    $scope.get_products();
                });
        }
        $scope.set_defaults();
    }]);
