groovepacks_admin_controllers.controller('DelayedJobCtrl', ['$scope', '$http', '$timeout', '$location', '$state', '$cookies', '$modal', '$q', 'notification', 'delayed_jobs',
    function ($scope, $http, $timeout, $location, $state, $cookies, $modal, $q, notification, delayed_jobs) {
      var myscope = {};

      myscope.delete = function (delayed_job_id, event) {
        delayed_jobs.list.destroy(delayed_job_id);
        myscope.init();
      };   

      // myscope.reset = function (current_delayed_job, event) {
      //   delayed_jobs.list.reset(current_delayed_job).success(
      //     function (data) {
      //       if (data.status) {
      //         notification.notify(data.messages, 1);
      //       } else {
      //         notification.notify(data.messages, 0);
      //       }
      //   });
      //   myscope.init();
      // };

      $scope.select_all_jobs_toggle = function (val) {
        delayed_job = $scope.delayed_jobs
        myscope.invert(false);
        delayed_job.setup.select_all = !!val;
        delayed_job.selected = [];
        delayed_job.list = $scope.new_delayed_jobs 
        for (var i = 0; i < delayed_job.list.length; i++) {
          delayed_job.list[i].checked = delayed_job.setup.select_all;
          if (delayed_job.setup.select_all) {
            myscope.select_single(delayed_job.list[i]);
          }
        }
      };

      // $scope.load_page = function (direction) {
      //   var page = parseInt($state.params.page, 10);
      //   return myscope.load_page_number(page);
      // };

      myscope.update_selected_count = function () {
        $scope.gridOptions.selections.selected_count = ($scope.delayed_jobs.setup.inverted && $scope.gridOptions.paginate.show) ? ($scope.gridOptions.paginate.total_items - $scope.delayed_jobs.selected.length) : $scope.delayed_jobs.selected.length;
      };

      myscope.invert = function (val) {
        delayed_job = $scope.delayed_jobs
        delayed_job.setup.inverted = !!val;
        if (delayed_job.setup.inverted) {
          if (delayed_job.setup.select_all) {
            $scope.select_all_jobs_toggle(false);
          } else if (delayed_job.selected.length == 0) {
            $scope.select_all_jobs_toggle(true);
          }
        }
        myscope.update_selected_count();
      };

      myscope.select_single = function (row) {
        delayed_jobs.single.select($scope.delayed_jobs, row);
      };

      myscope.select_jobs_pages = function (from, to, state) {
        delayed_jobs.list.select_pages($scope.delayed_jobs, from, to, state);
      };

      myscope.get_delayed_jobs = function (page) {
        if ($scope._can_load_delayed_jobs) {
          $scope.gridOptions.paginate.current_page = page;
          return delayed_jobs.list.get_searched($scope.delayed_jobs, page).success(function (data)  {
            $scope.new_delayed_jobs = data.delayed_jobs;
            $scope.gridOptions.paginate.total_items = data.total_count;
            myscope.update_selected_count();
          });
        }
      };

      myscope.handle_click_fn = function (row, event) {
        var toParams = {};
        toParams.delayed_id = row.id;
        var toState = 'tools.type.page.single';
        $scope.select_all_jobs_toggle(false);
        $state.go(toState, toParams);
      };

      myscope.load_page_number = function (page) {
        paginate_options = $scope.gridOptions.paginate
        if (page > 0 && page <= Math.ceil(paginate_options.total_items / paginate_options.items_per_page)) {
          return myscope.get_delayed_jobs(page);
        };
      };

      $scope.handle_sort = function (predicate) {
        myscope.common_setup_option('sort', predicate, 'delayed_job');
      };

      myscope.init = function () {
        $scope.delayed_jobs = delayed_jobs.model.get();
        $scope._can_load_delayed_jobs = true;
        $scope.current_page = 'delayed_jobs';
        $scope.tabs = [
          {
            page: 'delayed_jobs',
            open: true
          }
        ];
        //delayed_jobs.list.get().success(function (data)  {
        //  $scope.new_delayed_jobs = data.delayed_jobs;
        //});
        $scope.gridOptions = {
          identifier: 'new_delayed_jobs',
          show_hide: true,
          selectable: true,
          draggable: true,
          sortable: true,
          scrollbar: true,
          sort_func: $scope.handle_sort,
          select_all: $scope.select_all_jobs_toggle,
          invert: myscope.invert,
          selections: {
            show_dropdown: true,
            single_callback: myscope.select_single,
            multi_page: myscope.select_jobs_pages,
            selected_count: 0,
            show: myscope.show_selected
          },
          setup: $scope.delayed_jobs.setup,
          paginate: {
            show: true,
            current_page: $state.params.page,
            items_per_page: $scope.delayed_jobs.setup.limit,
            delayed_jobs_count: 50000,
            callback: myscope.load_page_number
          },
          editable: {
            functions: {
                name: myscope.handle_click_fn,
                open: myscope.delete,
                reset: myscope.reset
            }
          },
          all_fields: {
            handler: {
              name: "Handler",
              editable: false
            },
            locked_at: {
              name: "Locked At"
            },
            locked_by: {
              name: "Locked By",
              editable: false
            },
            queue: {
              name: "Queue",
              editable: false
            },
            created_at: {
              name: "Created At",
              editable: false
            },
            updated_at: {
              name: "Updated At",
              editable: false
            },
            priority: {
              name: "Priority",
              editable: false
            },
            attempts: {
              name: "Attempts",
              editable: false
            },
            id: {
              name: "Delete",
              editable: false,
              transclude: '<button confirm-click="Are you sure? You want to delete delayed Job!" ng-click="options.editable.functions.open(row[field],$event)">Delete</button>'
            },
            // reset: {
            //   name: "Reset",
            //   editable: false,
            //   sortable: false,
            //   transclude: '<button confirm-click="Are you sure? You want to reset delayed Job!" ng-click="options.editable.functions.reset(row,$event)">Reset</button>'
            // },
            delayed_job_time: {
              name: "Delayed Time",
              editable: false,
              sortable: false
            }
          }
        };
         $scope.$watch('delayed_jobs.setup.search', function () {
            // if ($scope.delayed_jobs.setup.select_all) {
            //   $scope.select_all_jobs_toggle(false);
            // }
            myscope.get_delayed_jobs(1);
          });
          $scope.$watch('delayed_jobs.selected', myscope.update_selected_count, true);
      };

      myscope.common_setup_option = function (type, value, selector) {
        delayed_jobs.setup.update($scope.delayed_jobs.setup, type, value);
        myscope.get_delayed_jobs(1);
      };
      myscope.init();
}]);