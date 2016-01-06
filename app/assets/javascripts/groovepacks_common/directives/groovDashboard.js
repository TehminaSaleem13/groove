groovepacks_directives.directive('groovDashboard', ['$window', '$document', '$sce',
  '$timeout', '$interval', 'groovIO', 'orders', 'stores', 'notification', 'dashboard', 'dashboard_calculator', 'users',
  function ($window, $document, $sce, $timeout, $interval, groovIO, orders, stores,
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
        ]
        scope.toggle_dashboard_detail = function () {
          $('#dashboard').toggleClass('pdash-open');
          scope.dashbord_detail_open = !scope.dashbord_detail_open;
          if (scope.dashbord_detail_open) {
            scope.charts.init();
          }
        }

        scope.init = function () {
          scope.charts.type = 'packing_stats';
          scope.dashboard = dashboard.model.get();
          scope.exceptions.init_all();
        }

        scope.switch_tab = function (tab) {
          if (tab.heading == "Most Recent Exceptions") {
            scope.exceptions.type = "most_recent";
            scope.exceptions.retrieve.most_recent_exceptions();
          } else if (tab.heading == "Exceptions by Frequency") {
            scope.exceptions.type = "by_frequency";
            scope.exceptions.retrieve.exceptions_by_frequency();
          } else if (tab.heading == "Leader Board") {
            scope.leader_board.retrieve.leader_board();
          }
        }

        groovIO.on('dashboard_update', function (message) {
          console.log("message");
          console.log(message);
          console.log(scope.charts.days_filters[scope.charts.current_filter_idx].days);
          days = scope.charts.days_filters[scope.charts.current_filter_idx].days
          if(message.type == 'leader_info') {
            console.log(scope.leader_board.list);
            scope.leader_board.list = message.data;
            console.log(scope.leader_board.list);
          } else {
            for (var i = message.data.length - 1; i >= 0; i--) {
              console.log(message.data[i]);
              if (parseInt(message.data[i].duration, 10) == days) {
                if (message.type == 'main_summary') {
                  scope.dashboard.main_summary = message.data[i];
                } else if (message.type == 'daily_stat') {
                  scope.dashboard.packing_stats = message.data[i].packing_stats.daily_stats;
                  scope.dashboard.packed_item_stats = message.data[i].packed_item_stats;
                  scope.dashboard.packing_speed_stats = message.data[i].packing_speed_stats.daily_stats;
                } else if (message.type == 'user_avg_stat') {
                  scope.dashboard.avg_packing_accuracy_stats = message.data[i].packing_stats.avg_stats;
                  scope.dashboard.avg_packing_speed_stats = message.data[i].packing_speed_stats.avg_stats;
                };
              };
            };
          };
          console.log(scope.dashboard);
          console.log(scope.leader_board.list);
          // if (message.type == 'main_summary') {
          //   for (var i = message.data.length - 1; i >= 0; i--) {
          //     console.log(message.data[i]);
          //     if (parseInt(message.data[i].duration, 10) == days) {
          //       scope.dashboard.main_summary = message.data[i];
          //     };
          //   };
          //   console.log(scope.dashboard.main_summary);
          // } else if(message.type == 'leader_info') {
          //   console.log(scope.leader_board.list);
          //   scope.leader_board.list = message.data;
          //   console.log(scope.leader_board.list);
          // } else if(message.type == 'daily_stat') {
          //   console.log(message.data);
          //   for (var i = message.data.length - 1; i >= 0; i--) {
          //     console.log(message.data[i]);
          //     if (parseInt(message.data[i].duration, 10) == days) {
          //       scope.dashboard.packing_stats = message.data[i].packing_stats.daily_stats;
          //       scope.dashboard.packed_item_stats = message.data[i].packed_item_stats;
          //       scope.dashboard.packing_speed_stats = message.data[i].packing_speed_stats.daily_stats;
          //     };
          //   };
          //   console.log(scope.dashboard);
          // } else if(message.type == 'user_avg_stat'){
          //   console.log(message.data);
          //   for (var i = message.data.length - 1; i >= 0; i--) {
          //     console.log(message.data[i]);
          //     if (parseInt(message.data[i].duration, 10) == days) {
          //       scope.dashboard.avg_packing_accuracy_stats = message.data[i].packing_stats.avg_stats;
          //       scope.dashboard.avg_packing_speed_stats = message.data[i].packing_speed_stats.avg_stats;
          //     };
          //   };
          //   console.log(scope.dashboard);
          // };
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
            this.init();
          },
          init: function () {
            if (this.type == 'packed_item_stats') {
              this.retrieve.packed_item_stats(
                this.days_filters[this.current_filter_idx].days);
            } else if (this.type == 'packing_stats') {
              this.retrieve.packing_stats(
                this.days_filters[this.current_filter_idx].days)
            } else if (this.type == 'packing_speed_stats') {
              this.retrieve.packing_speed_stats(
                this.days_filters[this.current_filter_idx].days)
            }
            this.retrieve.main_summary(
              this.days_filters[this.current_filter_idx].days);
          },
          retrieve: {
            main_summary: function (days) {
              dashboard.stats.main_summary(days).then(function (response) {
                console.log("response");
                console.log(response);
                scope.dashboard.main_summary = response.data;
              });
            },
            packing_stats: function (days) {
              dashboard.stats.packing_stats(days).then(
                function (response) {
                  scope.dashboard.packing_stats = response.data.daily_stats;
                  scope.dashboard.avg_packing_accuracy_stats = response.data.avg_stats;
                });
            },
            packed_item_stats: function (days) {
              dashboard.stats.packed_item_stats(days).then(
                function (response) {
                  console.log("response");
                  console.log(response);
                  scope.dashboard.packed_item_stats = response.data;
                });
            },
            packing_speed_stats: function (days) {
              dashboard.stats.packing_speed_stats(days).then(
                function (response) {
                  scope.dashboard.packing_speed_stats = response.data.daily_stats;
                  scope.dashboard.avg_packing_speed_stats = response.data.avg_stats;
                });
            }
          },
          set_type: function (chart_mode) {
            scope.charts.type = chart_mode;
            this.init();
          }
        }

        scope.leader_board = {
          list: [],
          options: {
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
                editable: false
              },
              packing_time: {
                name: "Packing Time",
                editable: false
              }
            }
          },
          retrieve: {
            leader_board: function () {
              dashboard.stats.leader_board().then(
                function (response) {
                  console.log(response);
                  scope.leader_board.list = response.data;
                });
            }
          }
        }

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
              users.list.get(null).then(function (response) {
                scope.exceptions.users = response.data;
              })
            },
            exception_by_frequency: function () {
              scope.exceptions_by_frequency = {
                list: [],
                options: {
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
                      editable: false
                    },
                    frequency: {
                      name: "Frequency",
                      editable: false,
                      transclude: "<span>{{row[field]}} %</span>"
                    }
                  }
                }
              }
            },
            most_recent_exceptions: function () {
              scope.most_recent_exceptions = {
                list: [],
                options: {
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
                      editable: false
                    },
                    frequency: {
                      name: "Frequency",
                      editable: false,
                      transclude: "<span>{{row[field]}} %</span>"
                    }
                  }
                }
              }
            }
          },
          change_user: function (user_idx) {
            this.current_user_idx = user_idx
            if (scope.exceptions.type == "most_recent") {
              scope.exceptions.retrieve.most_recent_exceptions();
            } else if (scope.exceptions.type == "by_frequency") {
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
        }

        scope.xAxisTickFormatFunction = function () {
          return function (d) {
            return d3.time.format('%b %e, %Y')(moment.unix(d).toDate());
          }
        }

        scope.yAxisTickFormatFunction = function () {
          return function (d) {
            return d;
          }
        }
        scope.legendColorFunction = function () {
          return function (d) {
            return d.color;
          }
        };
        scope.toolTipContentFunction = function () {
          return function (key, x, y, e, graph) {
            var tooltipText = '';
            if (scope.charts.type == 'packing_stats') {

              var average_packing_accuracy = "-";
              for (idx = 0; idx < scope.dashboard.avg_packing_accuracy_stats.length;
                   idx++) {
                if (scope.dashboard.avg_packing_accuracy_stats[idx].key == key) {
                  average_packing_accuracy = scope.dashboard.avg_packing_accuracy_stats[idx].
                    avg_packing_accuracy;
                  break;
                }
              }
              return ('<div><h4 style="text-transform: capitalize; color:' + e.series.color +
              '">' + key + '</h4>' +
              '<span><strong>Date: </strong>' + x + '</span><br/>' +
              '<span><strong>Accuracy: </strong>' + e.point[1] + '% </span><br/>' +
              '<span><strong>Period Accuracy: </strong>' + average_packing_accuracy + '% </span><br/>' +
              '<span><strong>' + e.point[2] + ' Orders Scanned</strong></span><br/>' +
              '<span><strong>' + e.point[3] + ' Items Packed </strong></span><br/>' +
              '<span><strong>' + e.point[4] + ' Exceptions Recorded</strong></span>' +
              '</div>')
            } else if (scope.charts.type == 'packing_speed_stats') {
              avg_period_score = "-"
              for (idx = 0; idx < scope.dashboard.avg_packing_speed_stats.length;
                   idx++) {
                if (scope.dashboard.avg_packing_speed_stats[idx].key == key) {
                  avg_period_score = scope.dashboard.avg_packing_speed_stats[idx].
                    avg_period_score;
                  break;
                }
              }
              return ('<div><h4 style="text-transform: capitalize; color:' + e.series.color +
              '">' + key + '</h4>' +
              '<span><strong>Period Speed Score: </strong>' + avg_period_score + '% </span><br/>' +
              '<span><strong>Date: </strong>' + x + '</span><br/>' +
              '<span><strong>Daily Speed Score: </strong>' + y + '% </span><br/>' +
              '<span><strong>Avg. Time/Item: </strong>' + (100 - y) + '</span>' +
              '</div>')
            } else if (scope.charts.type == 'packed_item_stats') {
              tooltipText = y + ' items packed on ' + x
              return ('<div><h4 style="text-transform: capitalize; color:' + e.series.color +
              '">' + key + '</h4>' +
              '<span>' + tooltipText + '</span></div>')
            }

          }
        }

        scope.init();

      }
    }
  }]);

