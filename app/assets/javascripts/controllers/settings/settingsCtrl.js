groovepacks_controllers.
    controller('settingsCtrl', [ '$scope','$state','users','stores',
        function( $scope,$state,users,stores) {
            var myscope = {};
            myscope.init = function() {
                $scope.current_page = '';
                $scope.settings = {
                    users: {allow:false},
                    stores: {allow:false}
                };

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
                    },
                    {
                        page:'backup',
                        open:false
                    },
                    {
                        page: 'show_card_details',
                        open:false
                    }
                ];
            };

            $scope.check_reset_links = function() {
                stores.single.can_create().success(function(data) {
                    $scope.settings.stores.allow = data.can_create;
                });
                users.single.can_create().success(function(data) {
                    $scope.settings.users.allow = data.can_create;
                });
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
