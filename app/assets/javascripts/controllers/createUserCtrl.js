groovepacks_controllers.
    controller('createUserCtrl', [ '$scope', '$http', '$timeout', '$stateParams', '$location', '$state', '$cookies',
        function( $scope, $http, $timeout, $stateParams, $location, $state, $cookies) {
            var myscope = {};
            myscope.create_user = function() {
                $scope.setup_modal();
                $scope.$apply(function(){
                    $scope.$parent.edit_status = false;
                    $scope.$parent.show_password = true;
                    $scope.$parent.newUser = {};
                    $scope.$parent.newUser.active = true;
                    $scope.$parent.newUser.role = {};
                    $scope.$parent.showSelectBaseRole = true;
                });
                $scope.user_modal.modal('show');
            }
            $timeout(myscope.create_user);
}]);
