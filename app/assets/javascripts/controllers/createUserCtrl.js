groovepacks_controllers.
    controller('createUserCtrl', [ '$scope', '$http', '$timeout', '$stateParams', '$location', '$state', '$cookies',
        function( $scope, $http, $timeout, $stateParams, $location, $state, $cookies) {
            var myscope = {};
            myscope.create_user = function() {
                $scope.setup_modal();
                $scope.edit_status = false;
                $scope.show_password = true;
                $scope.newUser = {};
                $scope.newUser.active = true;
                $scope.user_modal.modal('show');
            }
            $timeout(myscope.create_user);
}]);
