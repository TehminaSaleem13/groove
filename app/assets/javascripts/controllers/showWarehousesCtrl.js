groovepacks_controllers.
controller('showWarehousesCtrl', [ '$scope', '$http', '$timeout', '$routeParams', '$location', '$route', '$cookies',
	'warehouses', function( $scope, $http, $timeout, $routeParams, $location, $route, $cookies, warehouses) {

    var myscope = {};

    myscope.setup_modal = function() {
        if($scope.warehouse_modal == null ) {
            $scope.warehouse_modal = $('#createWarehouse'+$scope.custom_identifier);
            $scope.warehouse_modal.on("hidden",function() {
                if(typeof $scope.warehouses.single.id != "undefined") {
                    $scope.submit();
                }
                $timeout(function(){
                    $location.path("/settings/showwarehouses");
                },200);
            });
        }
    }

    $scope.create_warehouse = function() {
        myscope.setup_modal();
        $scope.edit_status = false;
        $scope.show_password = true;
        $scope.warehouse_modal.modal('show');
        $scope.warehouses = warehouses.model.reset_single($scope.warehouses);
    }


    myscope.init = function() {
        $http.get('/home/userinfo.json').success(function(data){
            $scope.username = data.username;
        });
        $scope.custom_identifier  = Math.floor(Math.random()*1000);
        $('.modal-backdrop').remove();
        $scope.warehouse_modal = null;
        $scope.current_page="show_warehouses";
        $scope.show_password = true;
        $scope.warehouses = warehouses.model.get();
		$scope.list_warehouses();
    }




	$scope.submit = function() {
		/*call service */
		warehouses.single.create($scope.warehouses).then(function(response) {
            if(response.status) {
                $scope.list_warehouses();
                $scope.warehouses = warehouses.model.reset_single($scope.warehouses);
            }
        });
	}

	$scope.list_warehouses = function() {
		warehouses.list.get($scope.warehouses).then(function() {
 			if ($routeParams.action == "create") {
                 myscope.create_warehouse();
             }
		});
	}

	$scope.get_warehouse_users = function() {

	}

	$scope.remove_warehouse = function() {

	}

	myscope.init();
}]);