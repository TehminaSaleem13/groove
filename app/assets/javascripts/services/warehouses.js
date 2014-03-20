groovepacks_services.factory('warehouses',['$http','notification',function($http, notification) {


    //default object
    var get_default = function() {
        return {
            list: [],
            single: {
                inv_wh_info: {
                    name: '',
                    location: '',
                    status: ''
                },
                inv_wh_users: []
            },
            available_users: []
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
                	object.inv_wh_info = data.inv_wh_info;
                	object.inv_wh_users = data.inv_wh_users;
                } else {
                    notification.notify("Can't load list of products",0);
                }
            }
        ).error(notification.server_error);
    }

	var create_inv_wh = function(object) {
        var url = '/inventory_warehouse/create.json';
        var warehouse = object.single.inv_wh_info;

        return $http.post(url, warehouse).success(
            function(data) {
                if(data.status) {
                	get_list(object);
                } else {
                    notification.notify("Can't load list of products",0);
                }
            }
        ).error(notification.server_error);
    }

    var set_associated_user = function(index, user_id, set_unset, object) {
        object.available_users[index].checked = set_unset;
    }

    //Public facing API
    return {
        model: {
            get:get_default,
            reset_single: reset_single,
            set_associated_user: set_associated_user
        },
        list: {
            get: get_list,
            get_available_users: get_available_users
        },
        single: {
            get: get_single,
            create: create_inv_wh
        }
    };


}]);