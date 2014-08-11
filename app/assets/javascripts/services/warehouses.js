groovepacks_services.factory('warehouses',['$http','notification','$filter',function($http, notification,$filter) {

    var success_messages = {
        update_status: "Status updated Successfully",
        delete:"Deleted Successfully"
    };

    //default object
    var get_default = function() {
        return {
            setup: {
                sort: '',
                order: 'DESC',
                search: '',
                select_all: false,
                //for internal use
                status:'',
                inv_wh_ids:[]
            },
            list: [],
            single: {
                inv_wh_info: {},
                inv_wh_users: []
            },
            available_users: []
        };
    };

    var reset_single = function(object) {
        object.single = {};
        object.single.inv_wh_info = {};
        object.single.inv_wh_info.status = 'active';
        object.single.inv_wh_users = [];
        return object;
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
        return $http.get('/inventory_warehouse/index.json').success(function(data) {
                if(data.status) {
                    result = $filter('filter')(data.data.inv_whs,object.setup.search);
                    result = $filter('orderBy')(result,object.setup.sort,(object.setup.order=='DESC'));
                    object.list = result;
                } else {
                    notification.notify("Can't load list of inventory warehouses",0);
                }
        }).error(notification.server_error);
    };

    var update_list = function(action,warehouses) {
        if(["update_status","delete"].indexOf(action) != -1) {
            warehouses.setup.inv_wh_ids = [];
            for(var i =0; i < warehouses.list.length; i++) {
                if (warehouses.list[i].checked == true) {
                    warehouses.setup.inv_wh_ids.push(warehouses.list[i].info.id);
                }
            }
            var url = '';
            if(action == "delete") {
                url = '/inventory_warehouse/destroy.json';
            } else if(action == "update_status") {
                url = '/inventory_warehouse/changestatus.json';
            }

            return $http.put(url,warehouses.setup).success(function(data) {
                if(data.status) {
                    warehouses.setup.select_all =  false;
                    notification.notify(success_messages[action],1);
                } else {
                    notification.notify(data.error_messages,0);
                }
            }).error(notification.server_error);
        }
    };

    var get_available_users = function(object) {
        var url = '/inventory_warehouse/available_users.json';

        if (typeof object.single.inv_wh_info.id != "undefined") {
            url += '?inv_wh_id=' + object.single.inv_wh_info.id;
        }

        return $http.get(url).success(
            function(data) {
                if(data.status) {
                    object.available_users = data.data.available_users;
                } else {
                    notification.notify("Can't retrieve list of available users",0);
                }
            }
        ).error(notification.server_error);
    };

	var get_single = function(id, object) {
        
        var url = '/inventory_warehouse/show.json?id='+id;

        return $http.get(url).success(
            function(data) {
                if(data.status) {
                	object.single.inv_wh_info = data.data.inv_wh_info;
                	object.single.inv_wh_users = data.data.inv_wh_users;
                } else {
                    notification.notify("Can't retrieve warehouse with id:"+id,0);
                }
            }
        ).error(notification.server_error);
    };

	var create_single = function(object) {
        var url = '/inventory_warehouse/create.json';
        var warehouse = {};
        warehouse.inv_info = object.single.inv_wh_info;
        warehouse.inv_users = [];

        for (var i = 0; i < object.available_users.length; i++) {
            if (object.available_users[i].checked) {
                warehouse.inv_users.push(object.available_users[i].user_info.id);
            }
        }

        return $http.post(url, warehouse).success(
            function(data) {
                if(!data.status) {
                    notification.notify(data.error_messages,0);
                }
            }
        ).error(notification.server_error);
    };

    var update_single = function(object) {
        var url = '/inventory_warehouse/update.json';
        var warehouse = {};
        warehouse = object.single.inv_wh_info;

        return $http.post(url, warehouse).success(
            function(data) {
                if(data.status) {
                    notification.notify(data.error_messages,0);
                }
            }
        ).error(notification.server_error);
    };

    var update_inv_wh_user = function(user_id, inv_wh_id, object, add_user) {
        var manage_user_obj = {};
        manage_user_obj.id = inv_wh_id;
        manage_user_obj.user_id = user_id;
        var url = '';

        if (add_user) {
            url = '/inventory_warehouse/adduser.json';
        }
        else {
            url = '/inventory_warehouse/removeuser.json';
        }

        return $http.put(url, manage_user_obj).success(
            function(data) {
                if(data.status) {
                    get_available_users(object);
                } else {
                    notification.notify(data.error_messages,0);
                }
            }
        ).error(notification.server_error);
    };

    var toggle_associated_user = function(index, user_id, persist_with_server, object) {
        if (index < object.available_users.length) {
            object.available_users[index].checked = !object.available_users[index].checked;

            if (persist_with_server) {
                update_inv_wh_user(user_id, object.single.inv_wh_info.id, object, object.available_users[index].checked);
            }
        }
    };


    //Public facing API
    return {
        model: {
            get:get_default,
            reset_single: reset_single
        },
        setup: {
               update:update_setup
        },
        list: {
            get: get_list,
            update: update_list,
            get_available_users: get_available_users
        },
        single: {
            get: get_single,
            create: create_single,
            update: update_single,
            toggle_associated_user: toggle_associated_user
        }
    };


}]);
