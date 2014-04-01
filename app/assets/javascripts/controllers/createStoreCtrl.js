groovepacks_controllers.
    controller('createStoreCtrl', [ '$scope', '$http', '$timeout', '$stateParams', '$location', '$state', '$cookies',
        function( $scope, $http, $timeout, $stateParams, $location, $state, $cookies) {
            $scope.create_store = function() {
                $scope.setup_modal();
                $scope.edit_status = false;
                $scope.redirect = false;
                $scope.newStore = {};
                $scope.newStore.status = 1;
                $scope.ebay_show_signin_url = true;
                $scope.loading = false;
                $http.get('/store_settings/getebaysigninurl.json').success(function(data) {
                    if (data.ebay_signin_url_status)
                    {
                        $scope.ebay_signin_url = data.ebay_signin_url;
                        $scope.ebay_signin_url_status = data.ebay_signin_url_status;
                        $scope.ebay_sessionid = data.ebay_sessionid;
                    }

                }).error(function(data) {
                        $scope.ebay_signin_url_status = false;

                    });
                $scope.store_modal.modal('show');
            }
            $timeout($scope.create_store);
        }]);
