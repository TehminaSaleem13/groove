groovepacks_controllers.
    controller('settingsCtrl', [ '$scope', '$http', '$timeout', '$stateParams', '$location', '$state', '$cookies',
        function( $scope, $http, $timeout, $stateParams, $location, $state, $cookies) {
            var myscope = {};
            myscope.init = function()
            {
                $scope.current_page = '';
                $scope.tabs = [
                    {
                        page:'show_stores',
                        open:false
                    },
                    {
                        page:'show_users',
                        open:true
                    },
                    {
                        page:'system',
                        open:false
                    }
                ];
            };

            $scope.setup_page = function(page,current) {
                for(var i = 0; i < $scope.tabs.length; i++) {
                    if(page == $scope.tabs[i].page) {
                        $scope.tabs[i].open = true;
                        if(typeof current =='undefined') {
                            $scope.current_page = $scope.tabs[i].page;
                        } else {
                            $scope.current_page = current;
                        }
                    } else {
                        $scope.tabs[i].open = false;
                    }
                }
            };

            myscope.init();
        }
]);
