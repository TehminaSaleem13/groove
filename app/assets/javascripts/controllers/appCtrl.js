groovepacks_controllers.
    controller('appCtrl', [ '$rootScope', '$scope', '$http', '$timeout', '$interval', '$stateParams', '$location', '$state', '$cookies', '$filter', 'auth','notification','importOrders',
        function( $rootScope, $scope, $http, $timeout, $interval, $stateParams, $location, $state, $cookies, $filter, auth,notification,importOrders) {
        $scope.$on("user-data-reloaded", function(){
            $scope.current_user = auth;
        });

        $scope.$on("editing-a-var",function(event,data) {
            $scope.current_editing = data.ident;
        });
        $scope.notify = function(msg,type) {
            notification.notify(msg,type);
        }
        $rootScope.import_summary = {};
        var myscope = {};
        

        //call a method at timeout of say 60 seconds.
        myscope.get_status = function() {
            $http.get('/orders/import_status.json').success(
              function(response) {
                if (response.status) {
                  $rootScope.import_summary = response.data.import_summary;
                  $scope.import_time = {
                     time: response.data.import_summary.import_info.updated_at
                  }
                }
            }).error(function(data) {});
        }

        myscope.get_status();      
        
        $interval(myscope.get_status, 2000);

        $scope.get_import_summary = function() {
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
