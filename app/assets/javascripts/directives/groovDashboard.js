groovepacks_directives.directive('groovDashboard',['$window','$document','$sce',
  '$timeout','$interval','groovIO','orders','stores','notification',function (
    $window,$document,$sce,$timeout,$interval,groovIO,orders,stores,notification) {
    return {
      restrict:"A",
      templateUrl:"/assets/views/directives/dashboard.html",
      scope: {},
      link: function(scope,el,attrs) {
        scope.toggle_detail = function() {
          $('#dashboard').toggleClass('pdash-open');
          scope.detail_open = !scope.detail_open;
        }
      }
    }
  }]);

