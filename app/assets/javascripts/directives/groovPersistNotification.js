groovepacks_directives.directive('groovPersistNotification',['$window','$sce','$timeout','$rootScope',function ($window,$sce,$timeout,$rootScope) {
    return {
        restrict:"A",
        templateUrl:"/assets/views/directives/persistnotification.html",
        scope: {},
        link: function(scope,el,attrs) {
            var myscope = {};
            myscope.default = function() {
                return {
                    show:false,
                    percent:0,
                    type:'success',
                    message:''
                };
            };

            scope.notifications = {
                default_state: myscope.default()
            };
            scope.selected = 'default_state';

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



            $rootScope.$on('generate_barcode_status',function(event,message) {
                if(typeof scope.notifications['generate_barcode_status'] == 'undefined') {
                    scope.notifications['generate_barcode_status'] = myscope.default();
                }
                if(typeof message =="undefined") return;
                scope.selected = 'generate_barcode_status';
                scope.notifications['generate_barcode_status'].show = true;
                scope.notifications['generate_barcode_status'].percent = (message['current_order_position']/message['total_orders'])*100;
                var notif_message = '<b>Generating&nbsp;Packing&nbsp;Slips:</b>&nbsp;';
                if(message['status'] == "scheduled") {
                    scope.notifications['generate_barcode_status'].type = 'info';
                    notif_message += 'Queued&nbsp;'+message['total_orders']+'&nbsp;Orders';
                } else if(message['status'] == "in_progress") {
                    scope.notifications['generate_barcode_status'].type = 'warning';
                    notif_message += message['current_order_position']+'/'+message['total_orders']+'&nbsp;<b>Order&nbsp;#'+message['current_increment_id']+'</b>';
                } else if(message['status'] == "completed") {
                    scope.notifications['generate_barcode_status'].type = 'success';
                    notif_message += "Complete!";
                    $timeout(function() {
                        scope.selected = 'default_state';
                        scope.notifications['generate_barcode_status'] = myscope.default();
                    },10000);
                    $window.open(message.url);
                }
                scope.notifications['generate_barcode_status'].message = $sce.trustAsHtml(notif_message);
            });
        }
    };
}]);
