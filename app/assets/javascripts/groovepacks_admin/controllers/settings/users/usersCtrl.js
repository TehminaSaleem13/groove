groovepacks_admin_controllers.
controller('usersCtrl', [ '$scope', '$http', '$timeout', '$stateParams', '$location', '$state', '$cookies', 'auth', 'users',
    function( $scope, $http, $timeout, $stateParams, $location, $state, $cookies, auth, users) {

        var myscope = {};

        $scope.select_all_toggle = function(val) {
            $scope.users.setup.select_all = val;
            for( var user_index=0; user_index<= $scope.users.list.length-1; user_index++) {
                $scope.users.list[user_index].checked = $scope.users.setup.select_all;
            }
        };

        $scope.user_change_status = function(status) {
            $scope.users.setup.status = status;
            return users.list.update('update_status',$scope.users).then(function(data) {
                $scope.users.setup.status = "";
                myscope.get_users();
            });
        };

        $scope.user_delete = function() {
            return users.list.update('delete',$scope.users).then(function(data) {
                myscope.get_users();
            });
        };

        $scope.user_duplicate = function() {
            return users.list.update('duplicate',$scope.users).then(function(data) {
                myscope.get_users();
            });

        };

        myscope.handlesort = function(predicate) {
            myscope.user_setup_opt('sort',predicate);
        };

        myscope.user_setup_opt = function(type,value) {
            users.setup.update($scope.users.setup,type,value);
            myscope.get_users();
        };

        myscope.get_users = function() {
            return users.list.get($scope.users).then(function(){
                $scope.select_all_toggle();
                $scope.check_reset_links();
            });
        };

        myscope.init = function() {
            $scope.setup_page("show_users");
            $scope.users = users.model.get();
            myscope.get_users();



            $scope.gridOptions = {
                identifier:'user_settings',
                select_all: $scope.select_all_toggle,
                draggable:false,
                sortable:true,
                selectable:true,
                sort_func: myscope.handlesort,
                setup: $scope.users.setup,
                all_fields: {
                    username: {
                        name: "Username",
                        class:''
                    },
                    active: {
                        name:"Status",
                        transclude: '<span class="label label-default" ng-class="{\'label-success\': row.active}">' +
                                   '<span ng-show="row.active" class="active">Active</span>' +
                                   '<span ng-hide="row.active" class="inactive">Inactive</span>' +
                                   '</span>',
                        class:''
                    },
                    last_sign_in_at: {
                        name:"Last Login",
                        transclude: "<span>{{row[field] | date:'EEEE MM/dd/yyyy hh:mm:ss a'}}</span>",
                        class:''
                    },
                    //online:{
                    //    name:"Online",
                    //    transclude:'<span class=\'label label-default\' ng-class="{\'label-success\': row.online}">' +
                    //              '<span ng-show="row.online" class="active">Online</span>' +
                    //              '<span ng-hide="row.online" class="inactive">Not Online</span>' +
                    //              '</span>',
                    //    class:''
                    //},
                    'role.name':{
                        name:"Type",
                        transclude: '<span class=\'label label-default\' ng-class="{' +
                                   '\'label-danger\': row.role.name==\'Super Admin\',' +
                                   '\'label-warning\': row.role.name==\'Admin\',' +
                                   '\'label-success\': row.role.name==\'Manager\',' +
                                   '\'label-info\': row.role.name == \'Scan & Pack User\'}">' +
                                   '<span ng-show="row.role.display">{{row.role.name}}</span>' +
                                   '<span ng-hide="row.role.display">Custom</span>' +
                                   '</span>',
                        class:''
                    }
                }
            };
            if(typeof $scope.current_user!= 'undefined' && $scope.current_user.can('add_edit_users')) {
                $scope.gridOptions.all_fields.username.transclude ='<a ui-sref="settings.users.single({user_id:row.id})"' +
                                                                  ' ng-click="$event.stopPropagation();">{{row[field]}}</a>';
            }


            //$scope.custom_identifier  = Math.floor(Math.random()*1000);



            $scope.$watch('users.setup.search',myscope.get_users);
            $scope.user_modal_closed_callback = function(){$timeout(myscope.get_users,100)};
            //$('.modal-backdrop').remove();
            //$scope.user_modal = null;
            //$scope.currently_open = 0;
        };





        myscope.init();
}]);
