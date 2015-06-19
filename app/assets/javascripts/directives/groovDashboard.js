groovepacks_directives.directive('groovDashboard',['$window','$document','$sce',
  '$timeout','$interval','groovIO','orders','stores','notification', 'dashboard', function (
    $window,$document,$sce,$timeout,$interval,groovIO,orders,stores,notification, dashboard) {
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
        scope.packing_stats = dashboard.model.get();

        dashboard.stats.packing_stats('30', scope.packing_stats).then(function(response){
          console.log(response)
          scope.packing_stats = response.data;
          console.log(scope.packing_stats);
        });

        scope.xAxisTickFormatFunction = function() {
          return function(d){
            return d3.time.format('%H:%M')(moment.unix(d).toDate());
          }
        }

        scope.yAxisTickFormatFunction = function() {
          return function(d){
            return d;
          }
        }
        scope.legendColorFunction = function(){
            return function(d){
                return d.color;
            }
        };
        scope.toolTipContentFunction = function(){
          return function(key, x, y, e, graph) {
              return  'Super New Tooltip' +
                  '<h1>' + key + '</h1>' +
                    '<p>' +  y + ' at ' + x + '</p>'
          }
        }
      }
    }
  }]);

