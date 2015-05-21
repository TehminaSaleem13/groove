groovepacks_services.factory('exportsettings',['$http','notification',function($http, notification) {


    //default object
    var get_default = function() {
        return {
            single: {}
        };
    };

    var get_export_settings = function(settings) {
        var url = '/exportsettings/get_export_settings.json';

        return $http.get(url).success(
            function(data) {
                if(data.status) {
                    settings.single = data.data.settings;
                    settings.single.time_to_send_email = new Date(data.data.settings.time_to_send_email);
                } else {
                    notification.notify(data.error_messages,0);
                }
            }
        ).error(notification.server_error);
    };

    var update_export_settings = function(settings) {
        var url = '/exportsettings/update_export_settings.json';

        return $http.put(url, settings.single).success(
            function(data) {
                if(data.status) {
                    get_export_settings(settings);
                    notification.notify(data.success_messages,1);
                } else {
                    notification.notify(data.error_messages,0);
                }
            }
        ).error(notification.server_error);
    };

    //Public facing API
    return {
        model: {
            get:get_default
        },
        single: {
            update: update_export_settings,
            get: get_export_settings
        }
    };

}]);
