groovepacks_directives.directive('groovCommon',['importOrders','$rootScope', function ( importOrders,$rootScope) {
    return {
        restrict:"A",
        templateUrl:"/assets/partials/common.html",
        scope: {
            groovImport:"="
        },
        link: function(scope,el,attrs) {
            $rootScope.$on('$stateChangeStart',function(event) {
                if($(".modal").is(':visible')) {
                    event.preventDefault();
                }
                $(".modal").modal("hide");
                $(".modal-scrollable").hide();
            });
            scope.notifs = {};
            //Notification related calls
            scope.$on('notification',function(event,args) {
                scope.notifs = args.data;
            });

            //import All Orders function
            scope.groovImport = function () {
                //$('#importOrders').modal('show');
                importOrders.do_import(scope);
            }
        }
    };
}]);
