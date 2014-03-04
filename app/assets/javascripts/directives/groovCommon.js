groovepacks_directives.directive('groovCommon',['notification','importOrders','$rootScope', function (notification, importOrders,$rootScope) {
    return {
        restrict:"A",
        templateUrl:"/assets/partials/common.html",
        scope: {
            groovNotif: "=",
            groovImport:"="
        },
        link: function(scope,el,attrs) {
            $(".modal").on("click",function() {
                $(".modal").modal("refresh");
            });
            $rootScope.$on('$locationChangeSuccess',function() {
                $(".modal").modal("hide");
                $(".modal-scrollable").hide();
            });
            scope.notifs = {};
            //Notification related calls
            scope.$on('notification',function(event,args) {
                scope.notifs = args.data;
            });
            scope.groovNotif = function(msg,type) {
                notification.notify(msg,type);
            }

            //import All Orders function
            scope.groovImport = function () {
                $('#importOrders').modal('show');
                importOrders.do_import(scope);
            }
        }
    };
}]);
