groovepacks_services.factory('delayed_jobs', ['$http', 'notification', 'editable', '$window', function ($http, notification, editable, $window) {

  var get_default = function () {
    return {
      list: [],
      selected: [],
      single: {},
      current: 0,
      setup: {
        sort: "updated_at",
        order: "DESC",
        search: '',
        select_all: false,
        inverted: false,
        limit: 20,
        offset: 0,
        setting: '',
        status: ''
      },
      delayed_jobs_count: {},
      duplicate_name: ""
    };
  };

  var get_delayed_job_list = function () {
    var url = '';
    url = '/delayed_jobs.json'
    return $http.get(url).success(
              function (data) {
                if (data.status) {
                  data.total_count;
                  data.delayed_jobs;
                } else {
                  delayed_jobs = {};
                }
            });
  };

  var delete_deleyed_job = function(delayed_job_id) {
    var url = ''; 
    url = '/delayed_jobs_delete.json'
    return $http.post(url, delayed_job_id)
  };

  var reset_delayed_job = function(current_delayed_job) {
    var url = ''; 
    url = '/delayed_job_reset.json'
    return $http.post(url, current_delayed_job)
  };

  var update_setup = function (setup, type, value) {
    if (type == 'sort') {
      if (setup[type] == value) {
        if (setup.order == "DESC") {
          setup.order = "ASC";
        } else {
          setup.order = "DESC";
        }
      } else {
        setup.order = "DESC";
      }
    }
    setup[type] = value;
    return setup;
  };

  var get_sinlge = function (id, delayed_jobs) {
    return $http.get('/delayed_jobs/' + id + '.json').success(function (data) {
      if (data.delayed_job) {
        if (typeof delayed_jobs.single['basicinfo'] != "undefined" && data.delayed_job.basicinfo.id == delayed_jobs.single.basicinfo.id) {
          angular.extend(delayed_jobs.single, data.delayed_job);
        } else {
          delayed_jobs.single = {};
          delayed_jobs.single = data.delayed_job;
        }
      } else {
        delayed_jobs.single = {};
      }
    }).error(notification.server_error).success(editable.force_exit).error(editable.force_exit);
  };

  var select_single = function (delayed_jobs, row) {
    var found = false;
    for (var i = 0; i < delayed_jobs.selected.length; i++) {
      if (delayed_jobs.selected[i].id == row.id) {
        found = i;
        break;
      }
    }
    if (found !== false) {
      if (!row.checked) {
        delayed_jobs.selected.splice(found, 1);
      }
    } else {
      if (row.checked) {
        delayed_jobs.selected.push(row);
      }
    }
  };

  var select_list = function (delayed_jobs, from, to, state) {
    var url = '';
    var setup = delayed_jobs.setup;
    var from_page = 0;
    var to_page = 0;

    if (typeof from.page != 'undefined' && from.page > 0) {
      from_page = from.page - 1;
    }
    if (typeof to.page != 'undefined' && to.page > 0) {
      to_page = to.page - 1;
    }
    var from_offset = (from_page * setup.limit) + from.index;
    var to_limit = (to_page * setup.limit) + to.index + 1 - from_offset;

    if (setup.search == '') {
      url = '/delayed_jobs/search.json?search=' + setup.search;
    } else {
      url = '/delayed_jobs/search.json?search=' + setup.search;
    }
    url += '&is_kit=' + setup.is_kit + '&limit=' + to_limit + '&offset=' + from_offset;
    return $http.get(url).success(function (data) {
      if (data.status) {
        for (var i = 0; i < data.delayed_jobs.length; i++) {
          data.delayed_jobs[i].checked = state;
          select_single(delayed_jobs, data.delayed_jobs[i]);
        }
      } else {
        notification.notify("Some error occurred in loading the selection.");
      }
    });
  };

  var get_list = function (delayed_jobs, page) {
    var url = '';
    var setup = delayed_jobs.setup;
    if (typeof page != 'undefined' && page > 0) {
      page = page - 1;
    } else {
      page = 0;
    }
    delayed_jobs.setup.offset = page * delayed_jobs.setup.limit;
    url = '/delayed_jobs.json?search=' + setup.search + '&sort=' + setup.sort + '&order=' + setup.order;
    url += '&limit=' + setup.limit + '&offset=' + setup.offset;
    return $http.get(url).success(
      function (data) {
        data.delayed_jobs;
      }
    ).error(notification.server_error);
  };

  return {
    model: {
      get: get_default
    },
    setup: {
      update: update_setup
    },
    list: {
      select: select_list,
      get: get_delayed_job_list,
      get_searched: get_list,
      destroy: delete_deleyed_job,
      reset: reset_delayed_job
    },
    single: {
      get: get_sinlge,
      select: select_single
    }
  };
}]);
