groovepacks_services.factory('delayed_jobs', ['$http', 'notification', 'editable', '$window', function ($http, notification, editable, $window) {

  var get_default = function () {
    return {
      selected: [], list: [], single: {}, current: 0, delayed_jobs_count: {}, duplicate_name: "", 
      setup: { sort: "updated_at", order: "DESC", search: '', select_all: false, inverted: false, limit: 20, offset: 0, setting: '', status: ''}
    };
  };

  var get_delayed_job_list = function () {
    var url = '';
    url = '/delayed_jobs.json'
    return $http.get(url)
  };

  var delete_deleyed_job = function(delayed_job_id) {
    var url = ''; 
    url = '/delayed_jobs_delete.json'
    return $http.post(url, delayed_job_id)
  };

  var update_delayed_job = function(delayed_jobs, select_all){
    var url = ''; 
    url = '/delayed_jobs_update.json'
    delayed_jobs.setup.jobArray = [];
    delayed_jobs.setup.jobArray.push({select_all: select_all});
    for (var i = 0; i < delayed_jobs.list.length; i++) {
      if (delayed_jobs.list[i].checked == true) {
        delayed_jobs.setup.jobArray.push({id: delayed_jobs.list[i].id});
      }
    }
    return $http.post(url, delayed_jobs.setup.jobArray)
  };

  var reset_delayed_job = function(current_delayed_job) {
    var url = ''; 
    url = '/delayed_job_reset.json'
    return $http.post(url, current_delayed_job)
  };

  var update_setup = function (setup, type, value) {
    if (type === 'sort' && setup[type] === value) {
      if (setup.order === "DESC") {
        setup.order = "ASC";
      } else {
        setup.order = "DESC";
      }
    }
    setup[type] = value;
    return setup;
  };

  var get_single_job = function (id, delayed_jobs) {
    return $http.get('/delayed_jobs/' + id + '.json')
  };

  var select_single_job = function (delayed_jobs, row) {
    var found = false;
    for (var i = 0;  i < delayed_jobs.selected.length; i++) {
      if (delayed_jobs.selected[i].id === row.id) {
        found = i;
        break;
      }
    }
    ((found !== false) && (!row.checked)) ? delayed_jobs.selected.splice(found, 1) : delayed_jobs.selected.push(row);
  };

  var select_job_list = function (delayed_jobs, from, to, state) {
    var url = '';
    var from_page = 0;
    var to_page = 0;
    var setup = delayed_jobs.setup;
    if (from.page > 0) {
      from_page = from.page - 1;
    } else if (to.page > 0) {
      to_page = to.page - 1;
    }
    var from_offset = (from_page * setup.limit) + from.index;
    var to_limit = (to_page * setup.limit) + to.index + 1 - from_offset;
    url = '/delayed_jobs/search.json?search=' + setup.search;
    url += '&is_kit=' + setup.is_kit + '&limit=' + to_limit + '&offset=' + from_offset;
    return $http.get(url).success(function (data) {
      if (data.status) {
        for (var i = 0; i < data.delayed_jobs.length; i++) {
          data.delayed_jobs[i].checked = state;
          select_single_job(delayed_jobs, data.delayed_jobs[i]);
        }
      }
    });
  };

  var get_job_list = function (delayed_jobs, page) {   
    page = (typeof page !== 'undefined' && page > 0) ? page - 1 : 0;
    var url = '';
    var setup = delayed_jobs.setup;
    delayed_jobs.setup.offset = page * delayed_jobs.setup.limit;
    url = '/delayed_jobs.json?search=' + setup.search + '&sort=' + setup.sort + '&order=' + setup.order;
    url += '&limit=' + setup.limit + '&offset=' + setup.offset;
    return $http.get(url).success( function (data) {
      if (data.status) {
        delayed_jobs.list = data.delayed_jobs;
        delayed_jobs.delayed_jobs_count = data.total_count;
        delayed_jobs.current = false;
        for (var i = 0; i < delayed_jobs.list.length; i++) {
          if (delayed_jobs.single && typeof delayed_jobs.single['basicinfo'] !== "undefined") {
            if (delayed_jobs.list[i].id === delayed_jobs.single.basicinfo.id) {
              delayed_jobs.current = i;
            }
          }
          if (delayed_jobs.setup.select_all) {
            delayed_jobs.selected = [];
            delayed_jobs.list[i].checked = delayed_jobs.setup.select_all;
            select_single_job(delayed_jobs, delayed_jobs.list[i]);
          } else {
            for (var k = 0; k < delayed_jobs.selected.length; k++) {
              if (delayed_jobs.list[i].id === delayed_jobs.selected[k].id) {
                delayed_jobs.list[i].checked = delayed_jobs.selected[k].checked;
                break;
              }
            }
          }
        }
      }
    });
  };

  return {
    model: {
      get: get_default
    },
    setup: {
      update: update_setup
    },
    list: {
      select_pages: select_job_list,
      get: get_delayed_job_list,
      get_searched: get_job_list,
      destroy: delete_deleyed_job,
      reset: reset_delayed_job,
      update: update_delayed_job
    },
    single: {
      get: get_single_job,
      select: select_single_job
    }
  };
}]);
