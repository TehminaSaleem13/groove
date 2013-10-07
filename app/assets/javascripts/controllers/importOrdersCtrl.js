groovepacks_controllers.
controller('importOrdersCtrl', [ '$scope', '$http', '$timeout', '$routeParams', '$location', '$route', '$cookies',
    function( $scope, $http, $timeout, $routeParams, $location, $route, $q, $cookies) {
        $http.get('/home/userinfo.json').success(function(data){
            $scope.username = data.username;
            console.log($scope.username);
            $('#importOrders').modal('show');
        });

        $http.get('/orders/importallorders.json').success(function(data) {
            $scope.importsummary = data;
        }).error(function(data) {

        });

    }]);
