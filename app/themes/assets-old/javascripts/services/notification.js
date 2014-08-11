groovepacks_services.factory("notification", ['$timeout','$rootScope',function($timeout,$rootScope) {
    var id = 0;
    var notif_types =  {
        0: "error",
        1: "success",
        2: "notice",
        default: 0
    };
    var notifications = {};
    var queue_remove =function(notif_id) {
        $timeout(
            function() {
                delete notifications[notif_id];
                $rootScope.$broadcast('notification',{data:notifications});
            },
            //timeout based on number of notifications and
            Object.keys(notifications).length*1500 + (notifications[notif_id].msg.length*50)
        );
    };
    var notify =  function (msg,type) {
        if(typeof type != "number" ||  typeof notif_types[type] == "undefined") {
            type = notif_types["default"];
        }
        var alert = notif_types[type];
        if(typeof msg == "string") {
            msg = [msg];
        }
        for(i in msg) {
            id++;
            notifications[id] = {show:true , alert: alert, msg: msg[i]};
            queue_remove(id);
        }
        $rootScope.$broadcast('notification',{data:notifications});
    };
    return {
        notify: notify,
        server_error: function(data) {
            notify("Error contacting server",0);
        }
    };

}]);
