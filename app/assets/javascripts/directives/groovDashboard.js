groovepacks_directives.directive('groovDashboard',['$window','$document','$sce',
  '$timeout','$interval','groovIO','orders','stores','notification',function (
    $window,$document,$sce,$timeout,$interval,groovIO,orders,stores,notification) {
    return {
      restrict:"A",
      templateUrl:"/assets/views/directives/dashboard.html",
      scope: {},
      link: function(scope,el,attrs) {
        scope.dashbord_detail_open = false;
        scope.dash_tabs = [
          {
            "heading": "Home",
            "templateUrl": "/assets/views/directives/test.html"
          },
          {
            "heading": "Most Recent Exceptions",
            "templateUrl": "/assets/views/directives/test.html"
          },
          {
            "heading": "Exceptions by Frequency",
            "templateUrl": "/assets/views/directives/test.html"
          },
          {
            "heading": "Items by Exception rate",
            "templateUrl": "/assets/views/directives/test.html"
          },
          {
            "heading": "Leader Board",
            "templateUrl": "/assets/views/directives/test.html"
          }
        ]
        scope.toggle_dashboard_detail = function() {
          $('#dashboard').toggleClass('pdash-open');
          scope.dashbord_detail_open = !scope.dashbord_detail_open;
        }
      }
    }
  }]);

