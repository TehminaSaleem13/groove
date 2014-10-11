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

io.on('connection', setup_socket);


function setup_socket(socket) {
    var tenant_name = socket.request.session.tenant;
    var user_id = socket.request.session.user_id;

    check_setup_user(user_id,tenant_name,socket);
    console.log("User connected, here is all the data");
    console.log(socket.request.session);

    socket.on('disconnect', function() {
        console.log("Disconnected:",socket.request.sessionID);
        var index = redis_clients.tenants[tenant_name].users[user_id].instances.indexOf(socket.request.sessionID);
        if(index > -1) {
            redis_clients.tenants[tenant_name].users[user_id].instances.splice(index,1);
        }
        //TODO: Add some logic to set a time-out for disconnected connections.
    });
}

function setup_redis_client(namespace) {
    var client = redis.createClient();
    client.on('connect'     , log('redis connect: '+namespace));
    client.on('ready'       , log('redis ready: '+namespace));
    client.on('reconnecting', log('redis reconnecting: '+namespace));
    client.on('error'       , log('redis error: '+namespace));
    client.on('end'         , log('redis end: '+namespace));
    client.subscribe(namespace);
    client.on('message',function(channel,message) {
        message = JSON.parse(message);
        io.to(channel).emit(message.type,message.data);
    });
    return client;
}

function check_setup_user(user_id,tenant_name,socket) {
    check_setup_tenant(tenant_name,socket);
    socket.join(global_namespace);
    socket.join(socket.request.sessionID);
    socket.join(global_namespace+':'+tenant_name+':'+user_id);
    if(typeof redis_clients.tenants[tenant_name].users[user_id] === "undefined") {
        redis_clients.tenants[tenant_name].users[user_id] = {};
        redis_clients.tenants[tenant_name].users[user_id].global = setup_redis_client(global_namespace+':'+tenant_name+':'+user_id);
        redis_clients.tenants[tenant_name].users[user_id].instances = [];
    }

    if(redis_clients.tenants[tenant_name].users[user_id].instances.indexOf(socket.request.sessionID) === -1) {
        redis_clients.tenants[tenant_name].users[user_id].instances.push(socket.request.sessionID);
    }
    console.log(socket.id, "->",socket.request.sessionID);
    console.log(redis_clients.tenants[tenant_name].users[user_id].instances);
    while(redis_clients.tenants[tenant_name].users[user_id].instances.length > 1) {
        var current = redis_clients.tenants[tenant_name].users[user_id].instances.shift();
        console.log("logging out",current);
        io.to(current).emit('logout',{message:'too many connections'});
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

function log(type) {
    return function() {
        console.log(type, arguments);
    }
}
