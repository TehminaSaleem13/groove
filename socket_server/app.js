var VERSION = 'v1';
var global_namespace = 'groovepacker';
var redis = require('redis');
var cookie = require("cookie");
//Dial that port on a phone =D
var io = (require('socket.io')()).path('/socket').serveClient(true).listen(47668).of('/'+VERSION);

var redis_clients = {};
redis_clients.tenants = {};
redis_clients.global = setup_redis_client(global_namespace);

io.use(function(socket, next) {
    var data = socket.request;
    if (data.headers.cookie) {
        data.cookie = cookie.parse(data.headers.cookie);
        data.sessionID = data.cookie['_validation_token_key'];
        var redis_validator = redis.createClient();

        // retrieve session from redis using the unique key stored in cookies
        redis_validator.hget(['groovehacks:session', data.sessionID], function (err, session) {

            if (err || !session) {
                return next(new Error('Unauthorized user'));
            } else {
                // store session data in nodejs server for later use
                data.session = JSON.parse(session);
                return next();
            }

        });
    } else {
        return next(new Error('Unauthorized user'));
    }
});

io.on('connection', function (socket) {
    var tenant_name = socket.request.session.tenant;
    var user_id = socket.request.session.user_id;
    var fingerprint = 'groov_'+socket.request.sessionID + socket.request._query.fingerprint;
    check_setup_user(socket,fingerprint);

    socket.on('disconnect', function() {
        groov_log("Disconnected:")(fingerprint);
        if(redis_clients.tenants[tenant_name] && redis_clients.tenants[tenant_name].users[user_id]) {
            var index = redis_clients.tenants[tenant_name].users[user_id].instances.indexOf(fingerprint);
            if(index > -1) {
                redis_clients.tenants[tenant_name].users[user_id].instances.splice(index,1);
            }
        }
        //TODO: Add some logic to set a time-out for disconnected connections.
    });
});

function setup_redis_client(namespace) {
    var client = redis.createClient();
    client.on('connect'     , groov_log('redis connect: '+namespace));
    client.on('ready'       , groov_log('redis ready: '+namespace));
    client.on('reconnecting', groov_log('redis reconnecting: '+namespace));
    client.on('error'       , groov_log('redis error: '+namespace));
    client.on('end'         , groov_log('redis end: '+namespace));
    client.subscribe(namespace);
    client.on('message',function(channel,message) {
        message = JSON.parse(message);
        io.to(channel).emit(message.type,message.data);
    });
    return client;
}

function check_setup_user(socket,fingerprint) {
    var tenant_name = socket.request.session.tenant;
    var user_id = socket.request.session.user_id;
    check_setup_tenant(tenant_name,socket);
    socket.join(global_namespace);
    socket.join(fingerprint);
    socket.join(global_namespace+':'+tenant_name+':'+user_id);
    if(typeof redis_clients.tenants[tenant_name].users[user_id] === "undefined") {
        redis_clients.tenants[tenant_name].users[user_id] = {};
        redis_clients.tenants[tenant_name].users[user_id].global = setup_redis_client(global_namespace+':'+tenant_name+':'+user_id);
        redis_clients.tenants[tenant_name].users[user_id].instances = [];
    }

    if(redis_clients.tenants[tenant_name].users[user_id].instances.indexOf(fingerprint) === -1) {
        redis_clients.tenants[tenant_name].users[user_id].instances.push(fingerprint);
    }
    while(redis_clients.tenants[tenant_name].users[user_id].instances.length > 1) {
        var current = redis_clients.tenants[tenant_name].users[user_id].instances.pop();
        logout(current,'Too many connections. Closing this session. Please logout from other sessions to continue here.');
    }
}

function check_setup_tenant(tenant_name,socket) {
    socket.join(global_namespace+':'+tenant_name);
    if(typeof redis_clients.tenants[tenant_name] === "undefined") {
        redis_clients.tenants[tenant_name] = {};
        redis_clients.tenants[tenant_name].global = setup_redis_client(global_namespace+':'+tenant_name);
        redis_clients.tenants[tenant_name].users = {};
    }
}

function logout(room,message) {
    io.to(room).emit('logout',{message:message});
}

function groov_log(type) {
    return function() {
        console.log(type, arguments);
    }
}
