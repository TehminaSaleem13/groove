groovepacks_services.factory('scanPack',['$http','notification',function($http,notification) {

    var scan_order = function() {

    }

    return {
        rfo: {
            scan: scan_order
        }
    };
}]);
