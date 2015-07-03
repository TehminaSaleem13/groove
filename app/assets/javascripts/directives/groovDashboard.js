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
        scope.toggle_dashboard_detail = function() {
          $('#dashboard').toggleClass('pdash-open');
          scope.dashbord_detail_open = !scope.dashbord_detail_open;
        }

        scope.init = function() {
          scope.charts.type = 'packing_stats';
          scope.dashboard = dashboard.model.get();
          scope.charts.init();
          scope.exceptions.init_all();
        }

        scope.switch_tab = function(tab) {
          if(tab.heading == "Most Recent Exceptions") {
            scope.exceptions.type = "most_recent";
            scope.exceptions.retrieve.most_recent_exceptions();
          } else if (tab.heading == "Exceptions by Frequency") {
            scope.exceptions.type = "by_frequency";
            scope.exceptions.retrieve.exceptions_by_frequency();
          } else if (tab.heading == "Leader Board") {
            scope.leader_board.retrieve.leader_board();
          }
        }

        scope.charts = {
          type: 'packing_stats',
          current_filter_idx: 1,
          days_filters:[
            { id: 1, name: '7 days', days: '7'},
            { id: 2, name: '30 days', days: '30'},
            { id: 3, name: '90 days', days: '90'},
            { id: 4, name: '180 days', days: '180'},
            { id: 5, name: 'All time', days: '-1'}
          ],
          change_days_filter: function(index) {
            this.current_filter_idx = index;
            this.init();
          },
          init: function(){
            if(this.type == 'packed_item_stats') {
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
            main_summary: function(days){
              dashboard.stats.main_summary(days).then(function(response){
                scope.dashboard.main_summary = response.data;
              });
            },
            packing_stats: function(days) {
              dashboard.stats.packing_stats(days).then(
                function(response){
                  scope.dashboard.packing_stats = response.data;
              });
            },
            packed_item_stats: function(days) {
              dashboard.stats.packed_item_stats(days).then(
                function(response){
                  scope.dashboard.packed_item_stats = response.data;
              });
            },
            packing_speed_stats: function(days) {
              dashboard.stats.packing_speed_stats(days).then(
                function(response){
                  scope.dashboard.packing_speed_stats = response.data;
              });
            }
          },
          set_type: function(chart_mode) {
            scope.charts.type = chart_mode;
            this.init();
          }
        }

        scope.leader_board = {
          list:[],
          options: {
            // paginate:{
            //     show:true,
            //     //send a large number to prevent resetting page number
            //     total_items:2,
            //     current_page:1,
            //     items_per_page:1
            // },
            all_fields: {
              order_items: {
                name:"Order Items",
                editable: false
              },
              name:{
                name:"Name",
                editable: false
              },
              record_date: {
                name: "Record Date",
                editable: false
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
            leader_board: function() {
              scope.leader_board.list = [
                {
                  order_items: "10",
                  name: "John Sculley",
                  record_date: "10/11/2015",
                  increment_id: "12345678",
                  packing_time: "22:13"
                },
                {
                  order_items: "11",
                  name: "John Sculley",
                  record_date: "10/11/2014",
                  increment_id: "12345689",
                  packing_time: "22:11"
                }
              ]
            }
          }
        }

        scope.exceptions = {
          type: 'most_recent',
          user_id: '-1',
          init_all: function() {
            this.init.most_recent_exceptions();
            this.init.exception_by_frequency();
          },
          init: {
            exception_by_frequency: function() {
              scope.exceptions_by_frequency = {
                list: [],
                options: {
                  // paginate:{
                  //     show:true,
                  //     //send a large number to prevent resetting page number
                  //     total_items:2,
                  //     current_page:1,
                  //     items_per_page:1
                  // },
                  all_fields: {
                    created_at: {
                      name:"Date Recorded",
                      editable: false
                    },
                    description:{
                      name:"Exception Description",
                      editable: false
                    },
                    increment_id: {
                      name: "Order Number",
                      editable: false
                    },
                    frequency: {
                      name: "Frequency",
                      editable: false
                    }
                  }
                }
              }
            },
            most_recent_exceptions: function(){
              scope.most_recent_exceptions = {
                list: [],
                options: {
                  paginate:{
                      show:true,
                      //send a large number to prevent resetting page number
                      total_items: 50000,
                      current_page:1,
                      items_per_page:10
                  },
                  all_fields: {
                    created_at: {
                      name:"Date Recorded",
                      editable: false
                    },
                    description:{
                      name:"Exception Description",
                      editable: false
                    },
                    increment_id: {
                      name: "Order Number",
                      editable: false
                    },
                    frequency: {
                      name: "Frequency",
                      editable: false
                    }
                  }
                }
              }
            }
          },
          retrieve: {
            most_recent_exceptions: function() {
              dashboard.stats.exceptions(scope.exceptions.user_id, scope.exceptions.type).then(
                function(response){
                  console.log(response.data);
                  scope.most_recent_exceptions.list = response.data;
              });
            },
            exceptions_by_frequency: function() {
              dashboard.stats.exceptions(scope.exceptions.user_id, scope.exceptions.type).then(
                function(response){
                  console.log(response.data);
                  scope.exceptions_by_frequency.list = response.data;
              });
            }
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
              var tooltipText = '';
              if (scope.charts.type == 'packing_stats'){
                tooltipText = y + ' order scans on ' + x
              } else if (scope.charts.type == 'packing_speed_stats') {
                tooltipText = y + ' seconds per scan on '+ x
              } else if (scope.charts.type == 'packed_item_stats') {
                tooltipText = y + ' items packed on '+ x
              }
              return ('<div><h4 style="text-transform: capitalize; color:'+e.series.color+
                      '">' + key + '</h4>' +
                      '<span>' +  tooltipText + '</span></div>')
          }
        }

        scope.init();

      }
    }
  }]);

