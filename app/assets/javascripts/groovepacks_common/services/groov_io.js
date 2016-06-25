groovepacks_services.factory("groovIO", ['socketFactory', '$http', '$window', 'notification', '$timeout', function (socketFactory, $http, $window, notification, $timeout) {
  var groov_socket = null;
  var current_id = 0;
  var forwards = {};

  var connect = function () {
    if (groov_socket === null) {
      if (typeof io !== "undefined") {
        var socket_conn = io("http://socket.localpacker.com/v1", {
          query: 'fingerprint=' + new Fingerprint({
            canvas: true,
            screen_resolution: true
          }).get()
        });
        groov_socket = socketFactory({ioSocket: socket_conn, prefix: 'groove_socket:'});
        var to_del = [];
        for (var i in forwards) {
          if (forwards.hasOwnProperty(i)) {
            groov_socket.forward(forwards[i].events, forwards[i].scope);
            to_del.push(i);
          }
        }

        for (var j = 0; j < to_del.length; j++) {
          delete forwards[to_del[j]];
        }

        groov_socket.on('connect', function () {
          $http.get('/home/request_socket_notifs.json');
        });

        groov_socket.on('reconnect', function () {
          notification.notify("Server connection re-established!", 1);
        });
        groov_socket.on('logout', log_out);
        groov_socket.on('error', function (msg) {
          if (msg === "Unauthorized user") {
            log_out({message: msg});
          }
        });
        groov_socket.on('disconnect', function () {
          notification.notify("Server connection lost. Retrying...", 2);
        });
      } else {
        $timeout(function () {
          notification.notify("Could not connect to the socket server. Please refresh page. If you continue to see this error, contact us.")
        }, 1000);
        return false;
      }
    }
    return true;
  };

  var log_out = function (msg) {
    notification.notify(msg.message);
    $timeout(function () {
      $http.delete('/users/sign_out.json').then(function (data) {
        $window.location.href = '/users/sign_in';
      });
    }, 100);
  };

  var emit = function (eventName, data, callback) {
    if (connect()) {
      data = data || {};
      data['headers'] = data['headers'] || {};
      return groov_socket.emit(eventName, data, callback);
    }
    return angular.noop;
  };

  var disconnect = function (close) {
    if (groov_socket === null) return;
    var result = groov_socket.disconnect(close);
    groov_socket = null;
    return result;
  };

  var callback = function (func, args) {
    if (connect()) {
      return groov_socket[func].apply(groov_socket, args);
    }
    return angular.noop;
  };

  var forward = function (events, scope) {
    if (groov_socket === null) {
      current_id++;
      forwards[current_id] = {scope: scope, events: events};
      setup_del_forward(current_id, scope);
    } else {
      groov_socket.forward(events, scope);
    }
  };

  var setup_del_forward = function (id, scope) {
    scope.$on('$destroy', function () {
      if (typeof forwards[current_id] != "undefined") {
        delete forwards[current_id];
      }
    });
  };

  var wrapped_response = {
    connect: connect,
    emit: emit,
    disconnect: disconnect,
    forward: forward,
    log_out: log_out
  };

  angular.forEach(['addListener', 'on', 'once', 'removeListener', 'removeAllListeners'], function (val) {
    this[val] = function () {
      return callback(val, arguments);
    }
  }, wrapped_response);


  return wrapped_response;

}]);
