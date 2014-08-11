groovepacks_controllers.
    controller('showBackupCtrl', [ '$scope', '$http', '$timeout', '$stateParams', '$location', '$state', '$cookies',
        function( $scope, $http, $timeout, $stateParams, $location, $state, $cookies) {
            var myscope = {};
            myscope.backup = function() {
                $("#backup").modal("show").on("hidden",function(){
                    $timeout(function(){
                        $scope.init();
                        $state.go("settings.showstores");
                    },200);
                });
            }
            $timeout(myscope.backup);
        }]);
