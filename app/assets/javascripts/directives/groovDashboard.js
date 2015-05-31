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
        scope.chartConfig = {

          options: {
              //This is the Main Highcharts chart config. Any Highchart options are valid here.
              //will be overriden by values specified below.
              chart: {
                  type: 'bar'
              },
              tooltip: {
                  style: {
                      padding: 10,
                      fontWeight: 'bold'
                  }
              }
          },
          //The below properties are watched separately for changes.

          //Series object (optional) - a list of series using normal highcharts series options.
          series: [{
             data: [10, 15, 12, 8, 7]
          }],
          //Title configuration (optional)
          title: {
             text: 'Hello'
          },
          //Boolean to control showng loading status on chart (optional)
          //Could be a string if you want to show specific loading text.
          loading: false,
          //Configuration for the xAxis (optional). Currently only one x axis can be dynamically controlled.
          //properties currentMin and currentMax provied 2-way binding to the chart's maximimum and minimum
          xAxis: {
          currentMin: 0,
          currentMax: 20,
          title: {text: 'values'}
          },
          //Whether to use HighStocks instead of HighCharts (optional). Defaults to false.
          useHighStocks: false,
          //size (optional) if left out the chart will default to size of the div or something sensible.
          size: {
           width: 400,
           height: 300
          },
          //function (optional)
          func: function (chart) {
           //setup some logic for the chart
          }
        };
      }
    }
  }]);

