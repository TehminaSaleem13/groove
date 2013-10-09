groovepacks_controllers.
controller('showProductsCtrl', [ '$scope', '$http', '$timeout', '$routeParams', '$location', '$route', '$cookies',
    function( $scope, $http, $timeout, $routeParams, $location, $route, $q, $cookies) {
    	$http.get('/home/userinfo.json').success(function(data){
    		$scope.username = data.username;
    	});

    	$scope.get_products = function(next) {
            next = typeof next !== 'undefined' ? next : false;
            if(!next) {
                $scope.product_setup.limit = 10;
                $scope.product_setup.offset = 0;
            }
            $http.get('/products/getproducts.json?filter='+$scope.product_setup.filter+'&sort='+$scope.product_setup.sort+'&order='+$scope.product_setup.order+'&limit='+$scope.product_setup.limit+'&offset='+$scope.product_setup.offset).success(function(data) {
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
            $scope.product_setup.limit = 10;
            $scope.product_setup.offset = 0;
            $(".product_setup-filter-active").addClass("active");
            $scope.get_products();
        }
        $scope.set_defaults();
    }]);
