groovepacks_services.factory("groovIO", ['socketFactory', '$http', '$window','notification','$timeout',function(socketFactory, $http, $window,notification,$timeout) {
    var groov_socket = null;

    var connect = function () {
        if(groov_socket === null) {
            if(typeof io !== "undefined") {
                var socket_conn = io("/v1");
                groov_socket = socketFactory({ioSocket: socket_conn, prefix:'groove_socket:'});
                groov_socket.on('connect',fingerprint);
                groov_socket.on('reconnect',function() {
                    notification.notify("Server connection re-established!",1);
                    fingerprint();
                });
                groov_socket.on('disconnect',function(){
                    notification.notify("Server connection lost. Please bear with us.",2);
                });
                groov_socket.on('logout',function(msg) {
                    notification.notify(msg.message);
                    notification.notify("Logging out in 10 seconds",2);
                    $timeout(function(){
                        $http.delete('/users/sign_out.json').then(function(data) {
                            $window.location.href = '/users/sign_in';
                        });
                    },10000);
                });
            } else {
                $timeout(function(){notification.notify("Could not connect to the socket server. Please refresh page. If you continue to see this error, contact us.")},1000);
                return false;
            }
        }
        return true;
    };

    var fingerprint = function() {
        console.log("Sending fingerprint");
        emit('fingerprint');
    };

    var emit = function (eventName,data,callback) {
        if(connect()){
            data = data || {};
            data['headers'] = data['headers'] || {};
            data['headers']['fingerprint'] = new Fingerprint({canvas: true,screen_resolution: true}).get();
            return groov_socket.emit(eventName,data,callback);
        }
        return angular.noop;
    };

    var disconnect = function(close) {
        if (groov_socket  === null) return;
        var result = groov_socket.disconnect(close);
        groov_socket = null;
        return result;
    };

    var callback = function(func,args) {
        if(connect()){
            return groov_socket[func].apply(groov_socket,args);
        }
        return angular.noop;
    };

    var wrapped_response = {
        emit:emit,
        disconnect:disconnect
    };

    angular.forEach(['addListener','forward','on','once','removeListener','removeAllListeners'],function(val) {
        this[val] = function() {return callback(val,arguments);}
    },wrapped_response);


    return wrapped_response;

}]);
