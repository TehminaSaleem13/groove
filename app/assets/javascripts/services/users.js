groovepacks_services.factory('users',['$http','notification','$filter',function($http,notification,$filter) {

    var success_messages = {
        update_status: "Status updated Successfully",
        delete:"Deleted Successfully",
        duplicate: "Duplicated Successfully"
    };
    var get_default = function() {
        return {
            list: [],
            single: {},
            roles:[],
            current: 0,
            setup:{
                sort: "",
                order: "DESC",
                search: '',
                select_all: false,
                //used for updating only
                status:'',
                userArray:[]
            }
        };
    };
    //Setup related function
    var update_setup = function (setup,type,value) {
        if(type =='sort') {
            if(setup[type] == value) {
                if(setup.order == "DESC") {
                    setup.order = "ASC";
                } else {
                    setup.order = "DESC";
                }
            } else {
                setup.order = "DESC";
            }
        }
        setup[type] = value;
        return setup;
    };

    //list related functions
    var get_list = function(object) {
        var result = [];
        return $http.get('/user_settings/userslist.json').success(
            function(data) {
                result = $filter('filter')(data,object.setup.search);
                result = $filter('orderBy')(result,object.setup.sort,(object.setup.order=='DESC'));
                object.list = result;
            }
        ).error(notification.server_error);
    };

    var update_list = function(action,users) {
        if(["update_status","delete","duplicate"].indexOf(action) != -1) {
            users.setup.userArray = [];
            for(var i = 0;  i< users.list.length; i++) {
                if (users.list[i].checked == true) {
                    users.setup.userArray.push({id: users.list[i].id,index:i,active:(users.setup.status =='active')});
                }
            }
            var url = '';
            if(action == "delete") {
                url = '/user_settings/deleteuser.json';
            } else if(action =="duplicate") {
                url = '/user_settings/duplicateuser.json';
            } else if(action == "update_status") {
                url = '/user_settings/changeuserstatus.json';
            }

            return $http.post(url,users.setup.userArray).success(function(data) {
                if(data.status) {
                    users.setup.select_all =  false;
                    notification.notify(success_messages[action],1);
                } else {
                    notification.notify(data.messages,0);
                }
            }).error(notification.server_error);
        }
    };
    //Roles related functions
    var get_roles = function(users) {
        return $http.get('/user_settings/getRoles.json').success(function(data) {
            if(data.status) {
                users.roles = data.roles;
            }
        }).error(notification.server_error);
    };

    var create_role = function(users) {
        return $http.put('/user_settings/createRole.json', users.single).success(function(data){
            if (data.status) {
                notification.notify("Role successfully applied",1);
                users.single.role = data.role;
            } else {
                notification.notify(data.messages,0);
            }
        }).error(notification.server_error);
    };
    var delete_role = function(users) {
        return $http.post('/user_settings/deleteRole.json',users.single).success(function(data){
            if (data.status) {
                notification.notify("Role successfully deleted",1);
                users.single.role = data.role;
            }
            else {
                notification.notify(data.messages,0);
            }
        }).error(notification.server_error);
    };

    //single user related functions
    var get_single = function(id,users) {
        return $http.get('/user_settings/getuserinfo.json?id='+id).success(function(data) {
            users.single = {};
            if(data.status) {
                users.single = data.user;
            }
        }).error(notification.server_error);
    };

    var can_create_single = function () {
        return $http.get('/user_settings/let_user_be_created.json')
    };

    var validate_single = function(users, auto, edit_status) {
        if (typeof auto !== 'boolean') auto = true;
        if(!auto) return true;
        var valid = true;
        console.log(users.single);
        if (typeof users.single.username == 'undefined' ||
            users.single.username == null || users.single.username == '') {
            valid &= false;
        }
        if (edit_status) {
                    console.log(users.single.confirmation_code);
            if (typeof users.single.confirmation_code == 'undefined' ||
            users.single.confirmation_code == null || 
            users.single.confirmation_code == '') {
                valid &= false;
            }
        } else {
            if (typeof users.single.password == 'undefined' ||
            users.single.password == null || 
            users.single.password == '') {
                valid &= false;
            }

            if (typeof users.single.conf_password == 'undefined' ||
            users.single.conf_password == null || 
            users.single.conf_password == '') {
                valid &= false;
            }
        }
        notification.notify(valid);

        return (valid);
    };

    var create_update_single = function(users,auto) {
        if(typeof auto !== "boolean") {
            auto = true;
        }
        return $http.post('/user_settings/createUpdateUser.json',users.single).success(function(data) {
            if(data.status) {
                users.single = data.user;
                users.single.role = data.user.role;
                if(!auto) {
                    notification.notify("Successfully Updated",1);
                }
            } else {
                notification.notify(data.messages,0);
            }
        }).error(notification.server_error);
    };

    //Public facing API
    return {
        model: {
            get:get_default
        },
        setup: {
            update:update_setup
        },
        list: {
            get: get_list,
            update: update_list
        },
        roles: {
            get: get_roles,
            create: create_role,
            delete: delete_role
        },
        single: {
            get: get_single,
            can_create: can_create_single,
            validate:validate_single,
            update:create_update_single
        }
    };
}]);
