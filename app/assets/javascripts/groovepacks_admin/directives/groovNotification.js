groovepacks_admin_directives.directive('groovNotification', function () {
  return {
    restrict: "A",
    templateUrl: "/assets/views/directives/notification.html",
    scope: {},
    link: function (scope, el, attrs) {
      scope.notifs = {};
      //Notification related calls
      scope.$on('notification', function (event, args) {
        scope.notifs = args.data;
      });

      //import All Orders function
      //scope.groovImport = function () {
      //$('#importOrders').modal('show');
      //importOrders.do_import(scope);
      //}
    }
  };
});
