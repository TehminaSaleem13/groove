groovepacks_controllers.
controller('showWarehousesCtrl', [ '$scope', '$http', '$timeout', '$routeParams', '$location', '$route', '$cookies',
	'warehouses', function( $scope, $http, $timeout, $routeParams, $location, $route, $cookies, warehouses) {

    var myscope = {};

    myscope.setup_modal = function() {
        if($scope.warehouse_modal == null ) {
            $scope.warehouse_modal = $('#createWarehouse'+$scope.custom_identifier);
            $scope.warehouse_modal.on("hidden", function() {
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
        $scope.warehouses = warehouses.model.reset_single($scope.warehouses);
        warehouses.list.get_available_users($scope.warehouses).then(function(response){
          if(response.status) {
            $scope.warehouse_modal.modal('show');   
          }
        })

    }

    $scope.select_toggle_user = function(index, user_id) {
        //if in edit mode, then use the selected index and update the server 
        //to add this user to the list of associated users.
        if ($scope.edit_status) {
            warehouses.model.toggle_associated_user(index, user_id, 
                true, $scope.warehouses); 
        }
        else {
            // if not in edit mode, toggle the active
            warehouses.model.toggle_associated_user(index, user_id, 
                false, $scope.warehouses); 
        }
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
        if ($scope.edit_status) {
        /*call service */
        warehouses.single.update($scope.warehouses).then(function(response) {
            if(response.status) {
                $scope.list_warehouses();
                $scope.warehouses = warehouses.model.reset_single($scope.warehouses);
            }
        });
        }
        else {
        /*call service */
        warehouses.single.create($scope.warehouses).then(function(response) {
            if(response.status) {
                $scope.list_warehouses();
                $scope.warehouses = warehouses.model.reset_single($scope.warehouses);
            }
        });
        }
	}

	$scope.list_warehouses = function() {
		warehouses.list.get($scope.warehouses).then(function() {
 			if ($routeParams.action == "create") {
                 myscope.create_warehouse();
             }
		});
	}

    $scope.list_available_users = function() {
        warehouses.list.get_available_users($scope.warehouses);
    }

	$scope.get_warehouse_users = function() {

	}

	$scope.remove_warehouse = function() {

	}

    $scope.edit_warehouse = function(warehouse_id) {
        myscope.setup_modal();
        $scope.edit_status = true;
        $scope.warehouses = warehouses.model.reset_single($scope.warehouses);
        warehouses.single.get(warehouse_id, $scope.warehouses).then(function(response){
          if(response.status) {
            warehouses.list.get_available_users($scope.warehouses).then(function(response){
              if(response.status) {
                $scope.warehouse_modal.modal('show');
              }
            });  
          }
        })
    }

	myscope.init();
}]);