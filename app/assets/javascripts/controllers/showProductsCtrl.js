groovepacks_controllers.
controller('showProductsCtrl', [ '$scope', '$http', '$timeout', '$routeParams', '$location', '$route', '$cookies',
    function( $scope, $http, $timeout, $routeParams, $location, $route, $q, $cookies) {
    	$http.get('/home/userinfo.json').success(function(data){
    		$scope.username = data.username;
    	});
    	
    	$http.get('/products/getproducts.json').success(function(data) {
    		$scope.products = data;
    	}).error(function(data) {

    	});

    }]);
