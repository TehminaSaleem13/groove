groovepacks_controllers.
    controller('showSettingsCtrl', [ '$scope', '$http', '$timeout', '$stateParams', '$location', '$state', '$cookies',
        function( $scope, $http, $timeout, $stateParams, $location, $state, $cookies) {
            $http.get('/home/userinfo.json').success(function(data){
                $scope.username = data.username;
            });
        }]);
