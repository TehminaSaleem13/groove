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

        scope.init = function() {
          scope.charts.type = 'packing_stats';
          scope.dashboard = dashboard.model.get();
          scope.charts.retrieve.packing_stats('30');
        }

        scope.charts = {
          type: 'packing_stats',
          change_days_filter: function(days) {
            if(scope.charts.type == 'packing_stats') {
              this.retrieve.packing_stats(days)
            } else if (scope.charts.type == 'packing_item_stats') {

            }
          },
          retrieve: {
            packing_stats: function(days) {
              dashboard.stats.packing_stats(days).then(
                function(response){
                  console.log("packing_stats")
                  console.log(scope.dashboard.packing_stats);
                  scope.dashboard.packing_stats = response.data;
              });
            }
          },
          set_type: function(chart_mode) {
            scope.charts.type = chart_mode;
          }
        }

        scope.xAxisTickFormatFunction = function() {
          return function(d){
            return d3.time.format('%a, %b %e, %Y')(moment.unix(d).toDate());
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

        scope.init();

      }
    }
  }]);

