groovepacks_services.factory('inventory_manager',['$http','notification',function($http, notification) {


    //default object
    var get_default = function() {
        return {
            single: {
              method: 'receive'
            }
        };
    }


	var post_receive_or_recount_inventory = function(inventory_manager_obj) {
        var url='/products/adjust_available_inventory.json';
        console.log(inventory_manager_obj);
        return $http.put(url, inventory_manager_obj.single).success(
            function(data) {
                if(!data.status) {
                    notification.notify(data.error_messages,0);
                }
            }
        ).error(notification.server_error);
    }

    //Public facing API
    return {
        model: {
            get:get_default
        },
        single: {
            update: post_receive_or_recount_inventory
        }
    };


}]);