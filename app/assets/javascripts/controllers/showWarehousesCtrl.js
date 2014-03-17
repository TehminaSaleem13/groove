groovepacks_controllers.
controller('showWarehousesCtrl', [ '$scope', '$http', '$timeout', '$routeParams', '$location', '$route', '$cookies',
	'warehouses', function( $scope, $http, $timeout, $routeParams, $location, $route, $cookies, warehouses) {

	$scope.current_page = 'show_warehouses';



	//Constructor
	$scope._init =function() {
		$scope.inv_wh_single = {};
		$scope.current_warehouse = {};
		$scope.inv_whs = [];
		$scope.warehouses = warehouses.model.get();
		$scope.list_warehouses();
	}

	$scope.add_warehouse = function() {
		/*call service */
		warehouses.single.create($scope.inv_wh_single, $scope.inv_whs);
	}

	$scope.list_warehouses = function() {
		warehouses.list.get($scope.warehouses).then(function(response) {
            //console.log("got products");
            $scope.inv_whs = $scope.warehouses.list;
            console.log($scope.warehouses);
            console.log($scope.inv_whs);
            // if(typeof post_fn == 'function' ) {
            //     //console.log("triggering post function on get products");
            //     $timeout(post_fn,30);
            // }
            // $scope.select_all_toggle(false);
            // $scope._can_load_products = true;
        });
	}

	$scope.get_warehouse_users = function() {

	}

	$scope.remove_warehouse = function() {

	}

	$scope._init();
}]);