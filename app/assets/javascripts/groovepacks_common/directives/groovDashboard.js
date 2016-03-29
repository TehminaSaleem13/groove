groovepacks_directives.directive('groovDashboard', ['$window', '$document', '$sce',
  '$timeout', '$interval', '$state', 'groovIO', 'orders', 'stores', 'notification', 'dashboard', 'dashboard_calculator', 'users',
  function ($window, $document, $sce, $timeout, $interval, $state, groovIO, orders, stores,
            notification, dashboard, dashboard_calculator, users) {
    return {
      restrict: "A",
      templateUrl: "/assets/views/directives/dashboard.html",
      scope: {},
      link: function (scope, el, attrs) {
        scope.dashbord_detail_open = false;
        scope.dash_tabs = [
          {
            "heading": "Home",
            "templateUrl": "/assets/views/directives/dashboard/home.html"
          },
          {
            "heading": "Most Recent Exceptions",
            "templateUrl": "/assets/views/directives/dashboard/most_recent_exceptions.html"
          },
          {
            "heading": "Exceptions by Frequency",
            "templateUrl": "/assets/views/directives/dashboard/most_recent_exceptions.html"
          },
          {
            "heading": "Leader Board",
            "templateUrl": "/assets/views/directives/dashboard/leader_board.html"
          }
        ];
        scope.toggle_dashboard_detail = function () {
          $('#dashboard').toggleClass('pdash-open');
          scope.dashbord_detail_open = !scope.dashbord_detail_open;
          // if (scope.dashbord_detail_open) {
          //   scope.charts.init();
          // }
        };

        scope.init = function () {
          scope.charts.type = 'packing_stats';
          scope.dashboard = dashboard.model.get();
          scope.dash_data = {};
          scope.exceptions.init_all();
          setTimeout(function(){
            dashboard.stats.dashboard_stat();
          }, 300);
        };

        scope.switch_tab = function (tab) {
          if (tab.heading === "Most Recent Exceptions") {
            scope.exceptions.type = "most_recent";
            scope.exceptions.retrieve.most_recent_exceptions();
          } else if (tab.heading === "Exceptions by Frequency") {
            scope.exceptions.type = "by_frequency";
            scope.exceptions.retrieve.exceptions_by_frequency();
          }
        }

        scope.update_max = function () {
          dashboard.model.update_max(scope.dashboard.max_time_per_item).then(function(){
            scope.build_dash_data();
          });
        }

        scope.handle_click_fn = function (row, event) {
          if (typeof event !== 'undefined') {
            event.stopPropagation();
          }
          var toState = 'orders.filter.page.single';
          var toParams = {};
          for (var key in $state.params) {
            if (['filter', 'page'].indexOf(key) !== -1) {
              toParams[key] = $state.params[key];
            }
          }
          orders.single.get_id(row['increment_id']).then(function(response) {
            toParams.order_id = response.data;
            scope.toggle_dashboard_detail();
            $state.go(toState, toParams);
          });
        };

        groovIO.on('dashboard_update', function (message) {
          days = scope.charts.days_filters[scope.charts.current_filter_idx].days;
          scope.dash_data = message.data;
          scope.build_dash_data();
        });

        scope.charts = {
          type: 'packing_stats',
          current_filter_idx: 1,
          days_filters: [
            {id: 1, name: '7 days', days: '7'},
            {id: 2, name: '30 days', days: '30'},
            {id: 3, name: '90 days', days: '90'},
            {id: 4, name: '180 days', days: '180'},
            {id: 5, name: 'All time', days: '-1'}
          ],
          change_days_filter: function (index) {
            this.current_filter_idx = index;
            scope.build_dash_data();
          },
          // init: function () {
          //   dashboard.stats.dashboard_stat();
          // },
          set_type: function (chart_mode) {
            if ((scope.charts.type == 'packing_error' && chart_mode == 'packing_stats') ||
              (scope.charts.type == 'packing_time_stats' && chart_mode == 'packing_speed_stats') ||
              (scope.charts.type == 'packed_order_stats' && chart_mode == 'packed_item_stats')) {
              return 0;
            } else {
              scope.charts.type = chart_mode;
            }
          },
          alter_type: function (chart_mode) {
            scope.charts.type = chart_mode;
          }
        };

        scope.leader_board = {
          list: [],
          options: {
            functions: {
              ordernum: scope.handle_click_fn
            },
            all_fields: {
              order_items_count: {
                name: "Order Items",
                editable: false
              },
              user_name: {
                name: "Name",
                editable: false
              },
              record_date: {
                name: "Record Date",
                editable: false,
                transclude: "<span>{{row[field] | date:'EEEE MM/dd/yyyy'}}</span>"
              },
              increment_id: {
                name: "Order Number",
                editable: false,
                transclude: '<a href="" ng-click="options.functions.ordernum(row,$event)" >{{row[field]}}</a>'
              },
              packing_time: {
                name: "Packing Time",
                editable: false
              }
            }
          }
        };

        scope.exceptions = {
          type: 'most_recent',
          current_user_idx: '0',
          users: [],
          init_all: function () {
            this.init.most_recent_exceptions();
            this.init.exception_by_frequency();
            this.init.users();
          },
          init: {
            users: function () {
              scope.exceptions.users.push({id: '-1', username: 'All User'});
              users.list.get(null).then(function (response) {
                response.data.forEach(function(element) {
                  if (element.active) {
                    scope.exceptions.users.push(element);
                  } else{
                    return;
                  }
                });
              });
            },
            exception_by_frequency: function () {
              scope.exceptions_by_frequency = {
                list: [],
                options: {
                  functions: {
                    ordernum: scope.handle_click_fn
                  },
                  all_fields: {
                    created_at: {
                      name: "Date Recorded",
                      editable: false,
                      transclude: "<span>{{row[field] | date:'EEEE MM/dd/yyyy'}}</span>"
                    },
                    description: {
                      name: "Exception Description",
                      editable: false
                    },
                    increment_id: {
                      name: "Order Number",
                      editable: false,
                      transclude: '<a href="" ng-click="options.functions.ordernum(row,$event)" >{{row[field]}}</a>'
                    },
                    frequency: {
                      name: "Frequency",
                      editable: false,
                      transclude: "<span>{{row[field]}} %</span>"
                    }
                  }
                }
              };
            },
            most_recent_exceptions: function () {
              scope.most_recent_exceptions = {
                list: [],
                options: {
                  functions: {
                    ordernum: scope.handle_click_fn
                  }, 
                  all_fields: {
                    created_at: {
                      name: "Date Recorded",
                      editable: false,
                      transclude: "<span>{{row[field] | date:'EEEE MM/dd/yyyy'}}</span>"
                    },
                    description: {
                      name: "Exception Description",
                      editable: false
                    },
                    increment_id: {
                      name: "Order Number",
                      editable: false,
                      transclude: '<a href="" ng-click="options.functions.ordernum(row,$event)" >{{row[field]}}</a>'
                    },
                    frequency: {
                      name: "Frequency",
                      editable: false,
                      transclude: "<span>{{row[field]}} %</span>"
                    }
                  }
                }
              };
            }
          },
          change_user: function (user_idx) {
            this.current_user_idx = user_idx;
            if (scope.exceptions.type === "most_recent") {
              scope.exceptions.retrieve.most_recent_exceptions();
            } else if (scope.exceptions.type === "by_frequency") {
              scope.exceptions.retrieve.exceptions_by_frequency();
            }
          },
          retrieve: {
            most_recent_exceptions: function () {
              dashboard.stats.exceptions(
                scope.exceptions.users[scope.exceptions.current_user_idx].id,
                scope.exceptions.type).then(
                function (response) {
                  scope.most_recent_exceptions.list = response.data;
                });
            },
            exceptions_by_frequency: function () {
              dashboard.stats.exceptions(
                scope.exceptions.users[scope.exceptions.current_user_idx].id,
                scope.exceptions.type).then(
                function (response) {
                  scope.exceptions_by_frequency.list = response.data;
                });
            }
          }
        };

        scope.xAxisTickValuesFunction = function () {
          return function(d){
            var tickVals = [];
            dates = [];
            dlen = d.length;
            for (var i = dlen - 1; i >= 0; i--) {
              ilen = d[i].values.length;
              for (var j = ilen - 1; j >= 0; j--) {
                if (d[i].disabled) {
                  break;
                } else {
                  dates.push(d[i].values[j][0]);
                }
              };
            };
            var max = Math.max.apply(Math,dates)
            var min = Math.min.apply(Math,dates)
            tickVals.push(min);
            if (parseInt((min + max) / 2) > (min + 86400)) {
              tickVals.push(parseInt(min + max) / 2);
            }
            tickVals.push(max);

            return tickVals;
          };
        };

        scope.yAxisTickValuesFunction = function () {
          return function(d){
            var tickVals = [];
            var vals = [];
            dlen = d.length;
            for (var i = dlen - 1; i >= 0; i--) {
              ilen = d[i].values.length;
              for (var j = ilen - 1; j >= 0; j--) {
                if (d[i].disabled) {
                  break;
                } else {
                  vals.push(d[i].values[j][1]);
                }
              };
            };
            vals.sort();
            max = Math.max.apply(Math,vals);
            min = Math.min.apply(Math,vals);
            div_range = (max - min) / 5;
            tickVals.push(min);
            temp = min;
            while (temp + div_range < max) {
              temp += div_range;
              if (temp.toFixed(2) % 1 == '0.00') {
                tickVals.push(Math.round( temp ));
              } else{
                tickVals.push(temp.toFixed(2));
              };
            };
            tickVals.push(max);
            return tickVals;
          };
        };

        scope.xAxisTickFormatFunction = function () {
          return function (d) {
            return d3.time.format('%b %e, %Y')(moment.unix(d).toDate());
          };
        };

        scope.yAxisTickFormatFunction = function () {
          return function (d) {
            return d;
          };
        };
        scope.legendColorFunction = function () {
          return function (d) {
            return d.color;
          };
        };
        scope.toolTipContentFunction = function () {
          return function (key, x, y, e, graph) {
            var tooltipText = '';
            if (scope.charts.type === 'packing_stats' || scope.charts.type === 'packing_error') {

              var average_packing_accuracy = "-";
              for (idx = 0; idx < scope.dashboard.avg_packing_accuracy_stats.length;
                   idx++) {
                if (scope.dashboard.avg_packing_accuracy_stats[idx].key === key) {
                  average_packing_accuracy = scope.dashboard.avg_packing_accuracy_stats[idx].
                    avg_packing_accuracy;
                  break;
                }
              }
              return ('<div><h4 style="text-transform: capitalize; color:' + e.series.color +
              '">' + key + '</h4>' +
              '<span><strong>Date: </strong>' + x + '</span><br/>' +
              '<span><strong>Accuracy: </strong>' + e.point[1] + '% </span><br/>' +
              '<span><strong>Period Accuracy: </strong>' + e.point[5] + '% </span><br/>' +
              '<span><strong>' + e.point[2] + ' Orders Scanned</strong></span><br/>' +
              '<span><strong>' + e.point[3] + ' Items Packed </strong></span><br/>' +
              '<span><strong>' + e.point[4] + ' Exceptions Recorded</strong></span>' +
              '</div>');
            } else if (scope.charts.type === 'packing_speed_stats' || scope.charts.type === 'packing_time_stats') {
              avg_period_score = "-";
              for (idx = 0; idx < scope.dashboard.avg_packing_speed_stats.length;
                   idx++) {
                if (scope.dashboard.avg_packing_speed_stats[idx].key === key) {
                  avg_period_score = scope.dashboard.avg_packing_speed_stats[idx].
                    avg_period_score;
                  break;
                }
              }
              return ('<div><h4 style="text-transform: capitalize; color:' + e.series.color +
              '">' + key + '</h4>' +
              '<span><strong>Period Speed Score: </strong>' + scope.get_speed(e.point[2]) + '% </span><br/>' +
              '<span><strong>Date: </strong>' + x + '</span><br/>' +
              '<span><strong>Daily Speed Score: </strong>' + scope.get_speed(y) + '% </span><br/>' +
              '<span><strong>Avg. Time/Item: </strong>' + y + ' sec</span>' +
              '</div>');
            } else if (scope.charts.type === 'packed_item_stats' || scope.charts.type === 'packed_order_stats') {
              tooltipText = y + ' items packed for ' + e.point[2] + ' orders on ' + x;
              return ('<div><h4 style="text-transform: capitalize; color:' + e.series.color +
              '">' + key + '</h4>' +
              '<span>' + tooltipText + '</span></div>');
            }

          };
        };

        scope.get_avg_time = function(time, items) {
          if (parseInt(items) === 0) {
            return 0;
          } else {
            return (parseInt(time) / parseFloat(items)).toFixed(2);
          }
        };

        scope.get_speed = function(avg) {
          console.log('avg', avg);
          if (avg === 0) {
            return 0;
          };
          var speed = scope.dashboard.max_time_per_item - avg;
          if (speed < 0) {
            return (100 + speed).toFixed(2);
          } else {
            return 100;
          }
        };

        scope.build_dash_data = function() {
          console.log('dash_data',scope.dash_data);
          scope.dashboard.max_time_per_item = 0;
          dashboard.model.get_max(scope.dashboard).then(function(response) {
            days = scope.charts.days_filters[scope.charts.current_filter_idx].days;
            scope.leader_board.list = scope.dash_data.leader_board.list;
            for (var i = 0; i <= scope.dash_data.dashboard.length - 1; i++) {
              if (parseInt(scope.dash_data.dashboard[i].duration, 10) === parseInt(days)) {
                scope.dashboard.main_summary = scope.dash_data.dashboard[i].main_summary;
                scope.dashboard.packing_stats = scope.dash_data.dashboard[i].daily_user_data.packing_stats;
                scope.dashboard.packed_item_stats = scope.dash_data.dashboard[i].daily_user_data.packed_item_stats;
                scope.dashboard.packing_speed_stats = scope.dash_data.dashboard[i].daily_user_data.packing_speed_stats;
                scope.dashboard.avg_packing_accuracy_stats = scope.dash_data.dashboard[i].avg_user_data.packing_stats;
                scope.dashboard.avg_packing_speed_stats = scope.dash_data.dashboard[i].avg_user_data.packing_speed_stats;
                var current_period_avg = scope.get_avg_time(scope.dashboard.main_summary.packing_time_summary.current_period, scope.dashboard.main_summary.packed_items_summary.current_period);
                var previous_period_avg = scope.get_avg_time(scope.dashboard.main_summary.packing_time_summary.previous_period, scope.dashboard.main_summary.packed_items_summary.previous_period);
                scope.dashboard.packing_time_summary.current_period = current_period_avg
                scope.dashboard.packing_time_summary.previous_period = previous_period_avg
                scope.dashboard.packing_time_summary.delta = (current_period_avg - previous_period_avg).toFixed(2);
                scope.dashboard.packing_speed_summary.current_period = scope.get_speed(current_period_avg);
                scope.dashboard.packing_speed_summary.previous_period = scope.get_speed(previous_period_avg);
                scope.dashboard.packing_speed_summary.delta =
                  (scope.dashboard.packing_speed_summary.current_period - scope.dashboard.packing_speed_summary.previous_period).toFixed(2);
                console.log(scope.dashboard);
              }
            }
          })
        };
        scope.init();
      }
    };
  }]);

