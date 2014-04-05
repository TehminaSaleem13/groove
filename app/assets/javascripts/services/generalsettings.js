groovepacks_services.factory('generalsettings',['$http','notification',function($http, notification) {


    //default object
    var get_default = function() {
        return {
            single: {}
        };
    }

    var get_settings = function(settings) {
        var url = '/settings/get_settings.json';

        return $http.get(url).success(
            function(data) {
                if(data.status) {
                    settings.single = data.data.settings;
                    console.log(settings);
                } else {
                    notification.notify(data.error_messages,0);
                }
            }
        ).error(notification.server_error);
    }

    var update_settings = function(settings) {
        var url = '/settings/update_settings.json';

        return $http.put(url, settings.single).success(
            function(data) {
                if(data.status) {
                    get_settings(settings);
                    notification.notify(data.success_messages,1);
                } else {
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
            update: update_settings,
            get: get_settings
        }
    };

}]);