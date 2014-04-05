groovepacks_services.factory('warehouses',['$http','notification',function($http, notification) {


    //default object
    var get_default = function() {
        return {
            list: [],
            single: {
                inv_wh_info: {},
                inv_wh_users: []
            },
            available_users: [],
            select_deselectall: false
        };
    }

    var reset_single = function(object) {
        object.single.inv_wh_info = {};
        object.single.inv_wh_users = [];
        return object;
    }

	var get_list = function(object) {
        
        var url = '/inventory_warehouse/index.json';

        return $http.get(url).success(
            function(data) {
                if(data.status) {
                	object.list = data.data.inv_whs;
                } else {
                    notification.notify("Can't load list of inventory warehouses",0);
                }
            }
        ).error(notification.server_error);
    }

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
    }

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
    }

	var create_inv_wh = function(object) {
        var url = '/inventory_warehouse/create.json';
        var warehouse = {};
        warehouse.inv_info = object.single.inv_wh_info;
        warehouse.inv_users = [];

        for (i = 0; i < object.available_users.length; i++) {
            if (object.available_users[i].checked) {
                warehouse.inv_users.push(object.available_users[i].user_info.id);
            }
        }

        return $http.post(url, warehouse).success(
            function(data) {
                if(data.status) {
                	get_list(object);
                } else {
                    notification.notify(data.error_messages,0);
                }
            }
        ).error(notification.server_error);
    }

    var update_inv_wh = function(object) {
        var url = '/inventory_warehouse/update.json';
        var warehouse = {};
        warehouse = object.single.inv_wh_info;

        return $http.post(url, warehouse).success(
            function(data) {
                if(data.status) {
                    get_list(object);
                } else {
                    notification.notify(data.error_messages,0);
                }
            }
        ).error(notification.server_error);
    }

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
    }

    var toggle_associated_user = function(index, user_id, persist_with_server, object) {
        if (index < object.available_users.length - 1) {
            if (object.available_users[index].checked) {
                object.available_users[index].checked = false
            }
            else {
                object.available_users[index].checked = true
            }

            if (persist_with_server) {
                update_inv_wh_user(user_id, 
                    object.single.inv_wh_info.id, object, 
                        object.available_users[index].checked);
            }
        }
    }

    var delete_wh = function(object) {
        var delete_ids = {};

        delete_ids.inv_wh_ids = [];
        
        for (i=0; i < object.list.length; i++) {
            if (object.list[i].checked) {
                delete_ids.inv_wh_ids.push(object.list[i].info.id);
            }
        }

        var url = '/inventory_warehouse/destroy.json';
        //sends a delete request
        return $http.put(url, delete_ids).success(
            function(data) {
                if(data.status) {
                    get_list(object);
                } else {
                    notification.notify(data.error_messages,0);
                }
            }
        ).error(notification.server_error);
    }

    var select_deselectall_event = function(object) {
        var unchecked  = false;
        for (i=0; i<object.list.length; i++){
            if (!object.list[i].checked) {
                unchecked = true;
                break;
            }
        }

        if (unchecked) {
            mark_checked = true;
        } else {
            mark_checked = false;
        }

        for (i=0; i<object.list.length; i++){
            object.list[i].checked = mark_checked;
        }

        object.select_deselectall = mark_checked;
    }

    var changestatus = function(object, status) {
        var changestatus_ids = {};

        changestatus_ids.inv_wh_ids = [];
        changestatus_ids.status = status;
        
        for (i=0; i < object.list.length; i++) {
            if (object.list[i].checked) {
                changestatus_ids.inv_wh_ids.push(object.list[i].info.id);
            }
        }

        var url = '/inventory_warehouse/changestatus.json';
        //sends a delete request
        return $http.put(url, changestatus_ids).success(
            function(data) {
                if(data.status) {
                    get_list(object);
                    object.select_deselectall = false;
                } else {
                    notification.notify(data.error_messages,0);
                }
            }
        ).error(notification.server_error);       

    }

    //Public facing API
    return {
        model: {
            get:get_default,
            reset_single: reset_single,
            toggle_associated_user: toggle_associated_user,
            select_deselectall_event: select_deselectall_event
        },
        list: {
            get: get_list,
            get_available_users: get_available_users,
            delete_wh: delete_wh,
            changestatus: changestatus
        },
        single: {
            get: get_single,
            create: create_inv_wh,
            update: update_inv_wh
        }
    };


}]);