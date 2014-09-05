groovepacks_controllers.
    controller('usersSingleModal', [ '$scope', 'user_data', '$state', '$stateParams','$modal', '$modalInstance', '$timeout', 'hotkeys', 'users','auth','notification',
        function(scope,user_data,$state,$stateParams,$modal, $modalInstance,$timeout,hotkeys,users,auth, notification) {

            var myscope = {};

            /**
             * Public methods
             */

            scope.ok = function() {
                $modalInstance.close("ok-button-click");
            };
            scope.cancel = function () {
                $modalInstance.dismiss("cancel-button-click");
            };

            scope.update = function(reason) {
                if(reason == "cancel-button-click") {
                    myscope.rollback();
                } else if(typeof scope.users.single.id != "undefined")  {
                    scope.update_single_user(false);
                }
            };

            scope.user_single_details = function(id,new_rollback) {
                for(var i =0; i< scope.users.list.length; i++) {
                    if(scope.users.list[i].id == id) {
                        scope.users.current = parseInt(i);
                        break;
                    }
                }
                return users.single.get(id,scope.users).then(function(data) {
                    myscope.load_roles();
                    scope.edit_status = true;
                    scope.show_password = false;
                    if(typeof new_rollback == 'boolean' && new_rollback ){
                        myscope.single = {};
                        angular.copy(scope.users.single,myscope.single);
                    }
                });
            };

            scope.update_single_user = function(auto) {
                return users.single.update(scope.users,auto).then(myscope.load_roles);
            };

            scope.make_new_role = function() {
                return users.roles.create(scope.users).then(myscope.load_roles);
            };

            scope.delete_role = function() {
                if(confirm("Are you sure you want to delete this role? All users with current role will be changed to Scan & Pack users")) {
                    users.roles.delete(scope.users).then(myscope.load_roles);
                }
            };


            scope.set_selected_role = function(event) {
                scope.roles_data.showSelectBaseRole = false;
                if(scope.roles_data.selectedRole != null) {
                    if(confirm("Are you sure?")) {
                        scope.users.single.role = scope.roles_data.selectedRole;
                        scope.update_single_user();
                    }
                } else {
                    scope.roles_data.showSelectBaseRole = true;
                    scope.users.single.role = {};
                }
            };

            scope.set_base_role = function(role) {
                scope.users.single.role = {};
                for(var i in role) {
                    if(role.hasOwnProperty(i) && i != "id" && i != "name") {
                        scope.users.single.role[i] = role[i];
                    }
                }
                scope.roles_data.showSelectBaseRole = false;
                notification.notify("Permissions from "+ role.name + " applied",1);
            };

            scope.change_password = function() {
                scope.show_password = true;
            };

            myscope.rollback = function() {
                scope.users.single = {};
                angular.copy(myscope.single,scope.users.single);
                scope.update_single_user();
            };
            /**
             * private properties
             */
            myscope.load_roles = function() {
                return users.roles.get(scope.users).then(myscope.reset_selected_role);
            };

            myscope.up_key = function(event) {
                event.preventDefault();
                event.stopPropagation();
                if(scope.edit_status) {
                    if(scope.users.current > 0) {
                        myscope.load_item(scope.users.current -1);
                    } else {
                        alert("Already at the top of the list");
                    }
                }
            };

            myscope.down_key = function (event) {
                event.preventDefault();
                event.stopPropagation();
                if(scope.edit_status) {
                    if(scope.users.current < scope.users.list.length - 1) {
                        myscope.load_item(scope.users.current +1);
                    } else {
                        alert("Already at the bottom of the list");
                    }
                }
            };

            myscope.left_key = function (event) {
                event.preventDefault();
                event.stopPropagation();
                var tabs_len = scope.modal_tabs.length-1;
                for (var i = 0; i <= tabs_len; i++) {
                    if(scope.modal_tabs[i].active) {
                        //scope.modal_tabs[i].active = false;
                        scope.modal_tabs[((i==0)? tabs_len : (i-1))].active = true;
                        break;
                    }
                }
            };

            myscope.right_key = function (event) {
                event.preventDefault();
                event.stopPropagation();
                var tabs_len = scope.modal_tabs.length-1;
                for (var i = 0; i <= tabs_len; i++) {
                    if(scope.modal_tabs[i].active) {
                        //scope.modal_tabs[i].active = false;
                        scope.modal_tabs[((i==tabs_len)? 0 : (i+1))].active = true;
                        break;
                    }
                }
            };

            myscope.load_item = function(id) {
                console.log(id);
                var newStateParams = angular.copy($stateParams);
                newStateParams.user_id = ""+scope.users.list[id].id;
                scope.user_single_details(scope.users.list[id].id, true);
                $state.go($state.current.name, newStateParams);
            };

            myscope.reset_selected_role = function() {
                scope.roles_data.selectedRole = null;
                //set role by reference for modal
                for(var i = 0; i < scope.users.roles.length; i++) {
                    if(scope.users.single.role.id  === scope.users.roles[i].id) {
                        scope.roles_data.selectedRole = scope.users.roles[i];
                        auth.check();
                    }
                }
            };

            myscope.init = function() {
                scope.users = user_data;
                //All tabs
                scope.modal_tabs = [
                    {
                        active:true,
                        heading:"User Info",
                        templateUrl:'/assets/views/modals/settings/user/info.html'
                    },
                    {
                        active:false,
                        heading:"Products",
                        templateUrl:'/assets/views/modals/settings/user/products.html'
                    },
                    {
                        active:false,
                        heading:"Orders",
                        templateUrl:'/assets/views/modals/settings/user/orders.html'
                    },
                    {
                        active:false,
                        heading:"User",
                        templateUrl:'/assets/views/modals/settings/user/user.html'
                    },
                    {
                        active:false,
                        heading:"System",
                        templateUrl:'/assets/views/modals/settings/user/system.html'
                    }
                ];
                $modalInstance.result.then(scope.update,scope.update);
                /**
                 * Public properties
                 */
                scope.roles_data = {};
                if(typeof $stateParams['user_id'] == 'undefined') {
                    scope.edit_status = false;
                    scope.show_password = true;
                    scope.users.single = {};
                    scope.users.single.active = true;
                    scope.users.single.role = {};
                    scope.roles_data.showSelectBaseRole = true;
                    myscope.load_roles().then(function() {
                        for(var i = 0; i < scope.users.roles.length; i++) {
                            if(scope.users.roles[i].name == 'Scan & Pack User') {
                                scope.users.single.role = scope.users.roles[i];
                                scope.roles_data.showSelectBaseRole = false;
                                myscope.reset_selected_role();
                                break;
                            }
                        }
                    });
                } else {
                    scope.edit_status = true;
                    scope.show_password = false;
                    scope.roles_data.showSelectBaseRole = false;
                    scope.user_single_details($stateParams['user_id'],true);
                }

                hotkeys.bindTo(scope).add({
                    combo: 'up',
                    description: 'Previous user',
                    callback: myscope.up_key
                }).add({
                    combo: 'down',
                    description: 'Next user',
                    callback: myscope.down_key
                }).add({
                    combo: 'left',
                    description: 'Previous tab',
                    callback: myscope.left_key
                }).add({
                    combo: 'right',
                    description: 'Next tab',
                    callback: myscope.right_key
                }).add({
                    combo: 'esc',
                    description: 'Save and close modal',
                    callback: function(){}
                });
            };
            myscope.init();
        }]);
