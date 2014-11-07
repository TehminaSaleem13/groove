var VERSION = 'v1';
var global_namespace = 'groovepacker';
var redis = require('redis');
var cookie = require("cookie");
//Dial that port on a phone =D
var io = (require('socket.io')()).path('/socket').serveClient(true).listen(47668).of('/'+VERSION);

var redis_clients = {};
redis_clients.tenants = {};
redis_clients.hasher = redis.createClient();
redis_clients.global = setup_redis_client(global_namespace);

io.use(function(socket, next) {
    var data = socket.request;
    if (data.headers.cookie) {
        data.cookie = cookie.parse(data.headers.cookie);
        data.sessionID = data.cookie['_validation_token_key'];

        // retrieve session from redis using the unique key stored in cookies
        redis_clients.hasher.hget(['groovehacks:session', data.sessionID], function (err, session) {

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
    var tenant_room = global_namespace+':'+tenant_name;
    var user_room = tenant_room+':'+user_id;
    check_setup_user(socket,fingerprint);
    push_persistent_notifications(socket);

    socket.on('logout_everyone_else', function() {
        var this_instance;
        if((this_instance = redis_clients.tenants[tenant_name].users[user_id].instances.indexOf(fingerprint)) !== -1) {
            redis_clients.tenants[tenant_name].users[user_id].instances.splice(this_instance,1);
        }
        while(redis_clients.tenants[tenant_name].users[user_id].instances.length) {
            var current = redis_clients.tenants[tenant_name].users[user_id].instances.pop();
            logout(current,'You have been logged out.');
        }
        redis_clients.tenants[tenant_name].users[user_id].instances.push(fingerprint);
    });

    setInterval(function() {
        check_ask_logout(redis_clients.tenants[tenant_name].users[user_id].instances,user_room);
    },5000);

    socket.on('delete_pnotif',function(hash) {
        groov_log("Deleting user pnotif hash:")(hash);
        redis_clients.hasher.hdel("groove_node:pnotif:"+user_room,hash);
    });

    socket.on('delete_tenant_pnotif',function(hash){
        groov_log("Deleting tenant pnotif hash:")(hash);
        redis_clients.hasher.hdel("groove_node:pnotif:"+tenant_room,hash);
    });

    socket.on('disconnect', function() {
        groov_log("Disconnected:")(fingerprint);
        if(redis_clients.tenants[tenant_name] && redis_clients.tenants[tenant_name].users[user_id]) {
            var index = redis_clients.tenants[tenant_name].users[user_id].instances.indexOf(fingerprint);
            if(index > -1) {
                redis_clients.tenants[tenant_name].users[user_id].instances.splice(index,1);
            }
            if(redis_clients.tenants[tenant_name].users[user_id].instances.length <= 1) {
                io.to(user_room).emit('hide_logout',{message:'Closed other sessions'});
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
        if(message.event == 'pnotif') {
            message.data.hash = message.data.type+'_'+message.data.data.id;
            redis_clients.hasher.hset("groove_node:pnotif:"+channel,message.data.hash,JSON.stringify(message.data));
        }
        io.to(channel).emit(message.event,message.data);
    });
    return client;
}

function check_setup_user(socket,fingerprint) {
    var tenant_name = socket.request.session.tenant;
    var user_id = socket.request.session.user_id;
    var room = global_namespace+':'+tenant_name+':'+user_id;
    check_setup_tenant(tenant_name,socket);
    socket.join(global_namespace);
    socket.join(fingerprint);
    socket.join(room);
    if(typeof redis_clients.tenants[tenant_name].users[user_id] === "undefined") {
        redis_clients.tenants[tenant_name].users[user_id] = {};
        redis_clients.tenants[tenant_name].users[user_id].global = setup_redis_client(global_namespace+':'+tenant_name+':'+user_id);
        redis_clients.tenants[tenant_name].users[user_id].instances = [];
    }

    if(redis_clients.tenants[tenant_name].users[user_id].instances.indexOf(fingerprint) === -1) {
        redis_clients.tenants[tenant_name].users[user_id].instances.push(fingerprint);
    }
    check_ask_logout(redis_clients.tenants[tenant_name].users[user_id].instances,room);
}

function check_setup_tenant(tenant_name,socket) {
    socket.join(global_namespace+':'+tenant_name);
    if(typeof redis_clients.tenants[tenant_name] === "undefined") {
        redis_clients.tenants[tenant_name] = {};
        redis_clients.tenants[tenant_name].global = setup_redis_client(global_namespace+':'+tenant_name);
        redis_clients.tenants[tenant_name].users = {};
    }
}
function push_persistent_notifications(socket) {
    var levels = [global_namespace,socket.request.session.tenant,socket.request.session.user_id];

    var current_key = "groove_node:pnotif";
    for (var i = 0; i < levels.length; i++) {
        current_key += ':'+levels[i];
        redis_clients.hasher.hgetall(current_key, function(err,hashes) {
            if (hashes === null) return;
            var all_data = [];
            for (var key in hashes) {
                if (hashes.hasOwnProperty(key)) {
                    //redis_clients.hasher.hdel(current_key,key);
                    var message = JSON.parse(hashes[key]);
                    message.data.hash = key;
                    all_data.push(message);
                }
            }
            io.to(socket.id).emit('pnotif',all_data);
        });

    }
}

function check_ask_logout(user_instances,room) {
    if(user_instances.length >1) {
        ask_logout(room,'Too many connections. Please logout other sessions to continue here.');
    }
}

function ask_logout(room,message) {
    io.to(room).emit('ask_logout',{message:message});
}

function logout(room,message) {
    io.to(room).emit('logout',{message:message});
}

function groov_log(type) {
    return function() {
        console.log(type, arguments);
    }
}
