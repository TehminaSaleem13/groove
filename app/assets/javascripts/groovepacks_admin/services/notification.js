groovepacks_admin_services.factory("notification", ['$timeout','$rootScope','$window',function($timeout,$rootScope,$window) {
    var id = 0;
    var notif_types =  {
        0: "danger",
        1: "success",
        2: "warning",
        default: 0
    };
    var notifications = {};

    var delete_notif = function(id) {
        delete notifications[id];
        $rootScope.$broadcast('notification',{data:notifications});
    };

    var queue_remove = function(notif_id) {
        $timeout(
            function() {delete_notif(notif_id);},
            //timeout based on number of notifications and
            Object.keys(notifications).length*1500 + (notifications[notif_id].msg.length*50)
        );
    };

    var notify =  function (msgs,type) {
        if(typeof type != "number" ||  typeof notif_types[type] == "undefined") {
            type = notif_types["default"];
        }
        var alert = notif_types[type];
        if(typeof msgs == "string") {
            msgs = [msgs];
        }
        for(var i = 0; i< msgs.length; i++) {
            for (var notif_id in notifications) {
                if(notifications.hasOwnProperty(notif_id) && notifications[notif_id].msg == msgs[i]) {
                    delete_notif(notif_id);
                    break;
                }
            }
            id++;
            notifications[id] = {show:true , alert: alert, msg: msgs[i]};
            queue_remove(id);
        }
        $rootScope.$broadcast('notification',{data:notifications});
    };
    return {
        notify: notify,
        server_error: function(data) {
            if(typeof data == 'object' && typeof data['error'] != "undefined" && data['error'] == "You need to sign in or sign up before continuing.") {
                $window.location.href ='/users/sign_in';
            }
            console.log(data);
            notify("Error contacting server",0);
        }
    };

}]);
