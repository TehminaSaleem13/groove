groovepacks_controllers.
    controller('appCtrl', [ '$scope', '$http', '$timeout', '$stateParams', '$location', '$state', '$cookies','auth','notification','importOrders',
        function( $scope, $http, $timeout, $stateParams, $location, $state, $cookies,auth,notification,importOrders) {
            $scope.$on("user-data-reloaded", function(){
                $scope.current_user = auth.get();
            });
            $scope.notify = function(msg,type) {
                notification.notify(msg,type);
            }
}]);
