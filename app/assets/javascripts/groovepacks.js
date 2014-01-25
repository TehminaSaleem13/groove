angular.module('groovepacks', ['groovepacks.filters', 'groovepacks.services', 'groovepacks.directives', 'groovepacks.controllers','ui.sortable', 'ngCookies', 'ngRoute','ngAnimate']).
  config(['$routeProvider', function($routeProvider) {
    $routeProvider.when('/orders',
    	{templateUrl: '/assets/partials/showorders.html', controller: 'showOrdersCtrl'});
    $routeProvider.when('/settings',
    	{templateUrl: '/assets/partials/showusers.html', controller: 'showUsersCtrl'});
    $routeProvider.when('/settings/showusers',
    	{templateUrl: '/assets/partials/showusers.html', controller: 'showUsersCtrl'});
    $routeProvider.when('/settings/showstores',
        {templateUrl: '/assets/partials/showstores.html', controller: 'showStoresCtrl'});
    $routeProvider.when('/products',
    	{templateUrl: '/assets/partials/showproducts.html', controller: 'showProductsCtrl'});
    $routeProvider.when('/scanandpack',
        {templateUrl: '/assets/partials/showscanandpack.html', controller: 'showScanPackCtrl'});
    $routeProvider.otherwise({redirectTo: '/settings/showstores'});
  }]).directive('xsInputSync', function() {
    return {
        restrict: "A",
        require: "?ngModel",
        link: function(scope, element, attrs, ngModel) {
            setInterval(function() {
                if (!(element.val()=='' && ngModel.$pristine))
                {
                    scope.$apply(function() {
                        ngModel.$setViewValue(element.val());
                    });
                }
                //console.log(scope);
            }, 100);
        }
    };
});

var groovepacks_controllers = angular.module('groovepacks.controllers', []);
var groovepacks_filters = angular.module('groovepacks.filters', []);
var groovepacks_services = angular.module('groovepacks.services', []);
var groovepacks_directives = angular.module('groovepacks.directives', []);

groovepacks_directives.directive('fileUpload', function () {
    return {
        scope: true,
        link: function (scope, el, attrs) {
            el.bind('change', function (event) {
                var file = event.target.files[0];
                scope.$emit("fileSelected", { name: attrs.name, file: file });
            });
        }
    };
});

groovepacks_services.factory('notification',function($timeout) {
        var scope = null;
        var id = 0;
        var notif_types =  {
            0: "error",
            1: "success",
            2: "notice",
            default: 0
        };
        var queue_remove =function(notif_id) {
            $timeout(
                function() {
                    delete scope.notifs[notif_id];
                },
                (Object.keys(scope.notifs).length-1)*1500 + 1500 + (scope.notifs[notif_id].msg.length*50)
            );
        };
        return {
            set_scope: function(scop) {
                scope = scop;
                scope.notifs = {};
            },
            notify: function (msg,type) {
                console.log();
                if(typeof type != "number" ||  typeof notif_types[type] == "undefined") {
                    type = notif_types["default"];
                }
                var alert = notif_types[type];
                if(typeof msg == "string") {
                    msg = [msg];
                }
                for(i in msg) {
                    id++;
                    scope.notifs[id] = {show:true , alert: alert, msg: msg[i]};
                    queue_remove(id);
                }
            }
        }
    }
)

groovepacks_services.factory("import_all", function($http) {
    return {
        do_import: function(scope) {

            /* Get all the active stores */
            $http.get('/store_settings/getactivestores.json').success(function(data) {
                    if (data.status)
                    {
                        //console.log("data status");
                        scope.active_stores = [];

                        for (var i = 0; i < data.stores.length; i++)
                        {
                            var activeStore = new Object();
                            activeStore.info = data.stores[i];
                            activeStore.message="";
                            activeStore.status="in_progress";
                            scope.active_stores.push(activeStore);
                        }
                        /* for each store send a import request */
                        for (var i = 0; i < scope.active_stores.length; i++)
                        {
                            //$scope.active_stores[i].status="in_progress";
                            //$timeout()
                            $http.get('/orders/importorders/'+scope.active_stores[i].info.id+'.json?activestoreindex='+i).success(
                                function(orderdata){

                                    if (orderdata.status)
                                    {
                                        scope.active_stores[orderdata.activestoreindex].status="completed";
                                        scope.active_stores[orderdata.activestoreindex].message = "Successfully imported "+orderdata.success_imported+
                                            " of "+orderdata.total_imported+" orders. "
                                            +orderdata.previous_imported+" orders were previously imported";
                                    }
                                    else
                                    {
                                        scope.active_stores[orderdata.activestoreindex].status="failed";
                                        for (var j=0; j< orderdata.messages.length; j++) {
                                            scope.active_stores[orderdata.activestoreindex].message += orderdata.messages[j];
                                        }
                                    }
                                }).error(function(data) {
                                    // console.log(data);
                                });
                        }

                    }
                    else
                    {
                        // console.log("data status false");
                        scope.message = "Getting active stores returned error.";
                    }
                }).error(function(data) {
                    scope.message = "Getting active stores failed.";
                });
            }
        }
    }
);
groovepacks_directives.directive('infiniteScroll', [
    '$rootScope', '$window', '$timeout', function($rootScope, $window, $timeout) {
        return {
            link: function(scope, elem, attrs) {
                var checkWhenEnabled, handler, scrollDistance, scrollEnabled;
                $window = angular.element($window);
                scrollDistance = 0;
                if (attrs.infiniteScrollDistance != null) {
                    scope.$watch(attrs.infiniteScrollDistance, function(value) {
                        return scrollDistance = parseInt(value, 10);
                    });
                }
                scrollEnabled = true;
                checkWhenEnabled = false;
                if (attrs.infiniteScrollDisabled != null) {
                    scope.$watch(attrs.infiniteScrollDisabled, function(value) {

                        scrollEnabled = !value;
                        if (scrollEnabled && checkWhenEnabled) {
                            checkWhenEnabled = false;
                            return handler();
                        }
                    });
                }
                handler = function() {
                    var elementBottom, remaining, shouldScroll, windowBottom;
                    windowBottom = $window.height() + $window.scrollTop();
                    elementBottom = elem.offset().top + elem.height();
                    remaining = elementBottom - windowBottom;
                    shouldScroll = remaining <= $window.height() * scrollDistance;
                    if (shouldScroll && scrollEnabled) {
                        if ($rootScope.$$phase) {
                            return scope.$eval(attrs.infiniteScroll);
                        } else {
                            return scope.$apply(attrs.infiniteScroll);
                        }
                    } else if (shouldScroll) {
                        return checkWhenEnabled = true;
                    }
                };
                $window.on('scroll', handler);
                scope.$on('$destroy', function() {
                    return $window.off('scroll', handler);
                });
                return $timeout((function() {
                    if (attrs.infiniteScrollImmediateCheck) {
                        if (scope.$eval(attrs.infiniteScrollImmediateCheck)) {
                            return handler();
                        }
                    } else {
                        return handler();
                    }
                }), 0);
            }
        };
    }
]);

String.prototype.chunk = function(size) {
    return [].concat.apply([],
        this.split('').map(function(x,i){
            return i%size ? [] : this.slice(i,i+size)
        }, this)
    )
}

String.prototype.trimmer = function (chr) {
    return this.replace((!chr) ? new RegExp('^\\s+|\\s+$', 'g') : new RegExp('^'+chr+'+|'+chr+'+$', 'g'), '');
}
