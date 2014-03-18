groovepacks_controllers.
controller('showWarehousesCtrl', [ '$scope', '$http', '$timeout', '$routeParams', '$location', '$route', '$cookies',
	'warehouses', function( $scope, $http, $timeout, $routeParams, $location, $route, $cookies, warehouses) {

	$scope.current_page = 'show_warehouses';



	//Constructor
	$scope._init =function() {
		$scope.warehouses = warehouses.model.get();
		$scope.list_warehouses();
	}

	$scope.add_warehouse = function() {
		/*call service */
		warehouses.single.create($scope.warehouses).then(function(response) {
            if(response.status) {
                $scope.list_warehouses();
                $scope.warehouses = warehouses.model.reset_single($scope.warehouses);
            }
        });
	}

	$scope.list_warehouses = function() {
		warehouses.list.get($scope.warehouses);
	}

	$scope.get_warehouse_users = function() {

	}

	$scope.remove_warehouse = function() {
		
	}

	$scope._init();
}]);