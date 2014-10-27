groovepacks_directives.directive('groovPersistNotification',['$window','$document','$sce','$timeout','groovIO','orders',function ($window,$document,$sce,$timeout,groovIO,orders) {
    return {
        restrict:"A",
        templateUrl:"/assets/views/directives/persistnotification.html",
        scope: {},
        link: function(scope,el,attrs) {
            var myscope = {};
            myscope.default = function() {
                return {
                    glow:false,
                    percent:0,
                    type:'success',
                    details:'',
                    message:''
                };
            };

            myscope.repurpose_selected = function () {
                if(typeof scope.notifications[scope.selected] == "undefined") {
                    scope.selected = '';
                }

                for(var i in scope.notifications) {
                    if(scope.notifications.hasOwnProperty(i)) {
                        if(scope.selected != '' && scope.notifications[scope.selected].type == 'in_progress') return;
                        if(scope.notifications[i].type == 'in_progress') {
                            scope.selected = i;
                        } else if(scope.notifications[i].percent < 100) {
                            if(scope.selected == '') {
                                scope.selected = i;
                            }
                            if (scope.notifications[i].type == 'paused') {
                                scope.selected = i;
                            }
                            if (scope.notifications[scope.selected].type == 'paused') continue;
                            if (scope.notifications[i].type == 'scheduled') {
                                scope.selected = i;
                            }
                            if (scope.notifications[scope.selected].type == 'scheduled') continue;
                            if (scope.notifications[i].type == 'cancelled') {
                                scope.selected = i;
                            }


                        }
                    }
                }
            };

            scope.notifications = {};
            scope.selected = '';
            scope.detail_open = false;
            groovIO.forward(['pnotif'],scope);
            /*
            var test = $interval(function() {
                scope.notifications['default_state'].show = true;
                scope.notifications['default_state'].percent += 10;
                scope.notifications['default_state'].type = 'warning';
                scope.notifications['default_state'].message = $sce.trustAsHtml('<b>Test:</b> '+scope.notifications['default_state'].percent+'/ 100');

                if(scope.notifications['default_state'].percent == 100) {
                    scope.notifications['default_state'].type = 'success';
                    scope.notifications['default_state'].message = $sce.trustAsHtml('<b>Test: Complete!</b>');
                    $interval.cancel(test);
                }
            },2000);
            */
            myscope.generate_barcode_status = function(message,hash) {
                scope.notifications[hash].percent = (message['current_order_position']/message['total_orders'])*100;
                var notif_message = '<b>Generating&nbsp;Packing&nbsp;Slips:</b>&nbsp;';
                var notif_details = '';
                notif_details +=' <b>Next Order&nbsp;#'+message['next_order_increment_id']+'</b>';
                scope.notifications[hash].type = message['status'];
                myscope.repurpose_selected();
                if(message['status'] == "scheduled") {
                    notif_message += 'Queued&nbsp;'+message['total_orders']+'&nbsp;Orders';
                } else if(message['status'] == "in_progress") {
                    notif_message += message['current_order_position']+'/'+message['total_orders']+'&nbsp;';
                    notif_details ='<b>Current Order&nbsp;#'+message['current_increment_id']+'</b> <br/>'+ notif_details;
                } else if(message['status'] == "completed" || message['status'] == "cancelled" ) {
                    notif_details = '';
                    $timeout(function() {
                        delete scope.notifications[hash];
                        myscope.repurpose_selected();
                    },5000);
                    groovIO.emit('delete_pnotif',hash);
                    if(message['status'] == "completed" ) {
                        notif_message += "Complete!";
                        $window.open(message.url);
                    } else if(message['status'] == "cancelled") {
                        notif_message += "Cancelled";
                    }
                }

                scope.notifications[hash].message = $sce.trustAsHtml(notif_message);
                scope.notifications[hash].details = $sce.trustAsHtml(notif_details);
                scope.notifications[hash].cancel = function($event) {
                    $event.preventDefault();
                    $event.stopPropagation();
                    orders.list.cancel_pdf_gen(message.id).then(function() {
                        myscope.repurpose_selected();
                    });
                };
            };

            scope.toggle_detail = function() {
                $document.find('body').eq(0).toggleClass('pnotif-open');
                scope.detail_open = !scope.detail_open;
                if(scope.detail_open) {
                    if(scope.selected == '') {
                        myscope.repurpose_selected();
                    }
                    scope.bar_glow = false;
                    for(var i in scope.notifications) {
                        if(scope.notifications.hasOwnProperty(i)) {
                            scope.notifications[i].glow = false;
                        }
                    }
                }
            };

            scope.$on('groove_socket:pnotif',function(event,messages) {
                if (messages instanceof Array === false) {
                    messages = [messages];
                }
                angular.forEach(messages,function(message) {
                    if(typeof myscope[message['type']] == "function") {
                        if(typeof message['data'] == "undefined") return;
                        if(typeof scope.notifications[message['hash']] == 'undefined') {
                            scope.notifications[message['hash']] = myscope.default();
                        }
                        if(scope.selected === '') {
                            scope.selected = message['hash'];
                        } else if(scope.selected !== message['hash']) {
                            scope.notifications[message['hash']].glow = true;
                            if(!scope.detail_open) {
                                scope.bar_glow = true;
                            }
                        }
                        myscope[message['type']](message['data'],message['hash']);
                    }
                });
            });
        }
    };
}]);
