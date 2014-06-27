groovepacks_controllers.
    controller('appCtrl', [ '$rootScope', '$scope', '$http', '$timeout', '$stateParams', '$location', '$state', '$cookies','auth','notification','importOrders',
        function( $rootScope, $scope, $http, $timeout, $stateParams, $location, $state, $cookies,auth,notification,importOrders) {
            $scope.$on("user-data-reloaded", function(){
                $scope.current_user = auth;
            });

            $scope.$on("editing-a-var",function(event,data) {
                $scope.current_editing = data.ident;
            });
            $scope.notify = function(msg,type) {
                notification.notify(msg,type);
            }
            $rootScope.import_in_progress = true;
            $rootScope.import_summary = {};
            //call a method at timeout of say 60 seconds.
            // $scope.get_status = function() {
            //     $http.get('/orders/import_status.json').success(function(data) {
            //         if (@result['import_summary']['status'] == 'in_progress') {
            //             $rootScope.import_in_progress = true;
            //         };
            //         else
            //             $rootScope.import_in_progress = false;
            //     }).error(function(data) {});
            // }
            // setTimeout(get_status, 60);
            $scope.get_import_summary = function() {
                console.log('importing mouse over');

                
                //console.log($(".popover-order a"));
                $("#ordersitem a").popover({
                    placement: 'bottom',
                    html: true, 
                    content: function() {
                      return $('#popoverExampleTwoHiddenContent').html();
                    },
                    title: function() {
                      return $('#popoverExampleTwoHiddenTitle').html();
                    }                    
                });
            }
}]);
