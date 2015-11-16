groovepacks_services.factory('tenants', ['$http', 'notification', 'editable', '$window', function ($http, notification, editable, $window) {

  // var success_messages = {
  //     update_status: "Status updated Successfully",
  //     delete: "Deleted Successfully",
  //     duplicate: "Duplicated Successfully",
  //     barcode: "Barcodes generated Successfully",
  //     receiving_label: "Labels generated Successfully",
  //     update_per_tenant: "Updated Successfully"
  // };

  //default object
  var get_default = function () {
    return {
      list: [],
      selected: [],
      single: {},
      current: 0,
      setup: {
        sort: "",
        order: "DESC",
        search: '',
        select_all: false,
        inverted: false,
        limit: 20,
        offset: 0,
        setting: '',
        status: ''
      },
      tenants_count: {},
      duplicate_name: ""
    };
  };

  //list related functions
  var get_list = function (tenants, page) {
    var url = '';
    var setup = tenants.setup;
    if (typeof page != 'undefined' && page > 0) {
      page = page - 1;
    } else {
      page = 0;
    }
    tenants.setup.offset = page * tenants.setup.limit;
    url = '/tenants.json?search=' + setup.search + '&sort=' + setup.sort + '&order=' + setup.order;
    url += '&limit=' + setup.limit + '&offset=' + setup.offset;
    return $http.get(url).success(
      function (data) {
        if (data.status) {
          tenants.load_new = (data.tenants.length > 0);
          tenants.tenants_count = data.tenants_count;
          tenants.list = data.tenants;
          tenants.current = false;
          if (tenants.setup.select_all) {
            tenants.selected = [];
          }
          for (var i = 0; i < tenants.list.length; i++) {
            tenants.list[i].popover = construct_popover(tenants.list[i]);
            if (tenants.single && typeof tenants.single['basicinfo'] != "undefined") {
              if (tenants.list[i].id == tenants.single.basicinfo.id) {
                tenants.current = i;
              }
            }
            if (tenants.setup.select_all) {
              tenants.list[i].checked = tenants.setup.select_all;
              select_single(tenants, tenants.list[i]);
            } else {
              for (var j = 0; j < tenants.selected.length; j++) {
                if (tenants.list[i].id == tenants.selected[j].id) {
                  tenants.list[i].checked = tenants.selected[j].checked;
                  break;
                }
              }
            }
          }
        } else {
          notification.notify("Can't load list of tenants", 0);
        }
      }
    ).error(notification.server_error);
  };

  var construct_popover = function(list) {
    var row_data = '';
    for (var i = 0; i < list.shipped_last6.length; i++) {
      row_data += '<tr><td>'+list.shipped_last6[i].shipping_duration+'</td><td>' + list.shipped_last6[i].shipped_count + '</td></tr>';
    };
    return '<table style="font-size: 13px;width:100%;font-weight:bold;">' + 
           '<tr style="border-bottom: 2px solid gray;"><td>Duration</td><td>Shipped Qty</td></tr>'.concat(row_data ,
            '</table>');
  }

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

  var total_tenants_list = function (tenants) {
    var total_items;
    if (tenants.setup.search != "") {
      total_items = tenants.tenants_count['search'];
    } else {
      total_items = tenants.tenants_count['all'];
    }
    if (typeof total_items == 'undefined') {
      total_items = 0;
    }
    return total_items;
  };

  var select_list = function (tenants, from, to, state) {
    var url = '';
    var setup = tenants.setup;
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
      url = '/tenants/gettenants.json?filter=' + setup.filter + '&sort=' + setup.sort + '&order=' + setup.order;
    } else {
      url = '/tenants/search.json?search=' + setup.search;
    }
    url += '&is_kit=' + setup.is_kit + '&limit=' + to_limit + '&offset=' + from_offset;
    return $http.get(url).success(function (data) {
      if (data.status) {
        for (var i = 0; i < data.tenants.length; i++) {
          data.tenants[i].checked = state;
          select_single(tenants, data.tenants[i]);
        }
      } else {
        notification.notify("Some error occurred in loading the selection.");
      }
    });

  };

  var update_list = function (tenants) {
    return $http.post('/tenants/delete_tenant.json', tenants.selected).success(function (data) {
      tenants.selected = [];
      if (data.status) {
        tenants.setup.select_all = false;
        tenants.setup.inverted = false;
        notification.notify(data.success_messages, 1);
      } else {
        notification.notify(data.error_messages, 0);
      }
      ;
    }).error(notification.server_error);
  }

  var update_list_node = function (obj) {
    return $http.post('/tenants/'+ obj.id +'/update_tenant_list.json', obj).success(function (data) {
      if (data.status) {
        notification.notify("Successfully Updated", 1);
      } else {
        notification.notify(data.error_msg, 0);
      }
    }).error(notification.server_error);
  };

  var select_single = function (tenants, row) {
    var found = false;
    for (var i = 0; i < tenants.selected.length; i++) {
      if (tenants.selected[i].id == row.id) {
        found = i;
        break;
      }
    }

    if (found !== false) {
      if (!row.checked) {
        tenants.selected.splice(found, 1);
      }
    } else {
      if (row.checked) {
        tenants.selected.push(row);
      }
    }
  };

  var get_sinlge = function (id, tenants) {
    return $http.get('/tenants/' + id + '.json').success(function (data) {
      if (data.tenant) {
        if (typeof tenants.single['basicinfo'] != "undefined" && data.tenant.basicinfo.id == tenants.single.basicinfo.id) {
          angular.extend(tenants.single, data.tenant);
        } else {
          tenants.single = {};
          tenants.single = data.tenant;
        }
      } else {
        tenants.single = {};
      }
    }).error(notification.server_error).success(editable.force_exit).error(editable.force_exit);
  };

  var update_access_restriction_data = function (tenants) {
    return $http.put('/tenants/' + tenants.single.basicinfo.id + '.json', tenants.single).success(function (data) {
      if (data.status) {
        notification.notify("Successfully Updated.", 1);
      } else {
        notification.notify(data.error_messages, 0);
      }
      ;
    }).error(notification.server_error);
  };

  var duplicate_tenant = function (tenants) {
    return $http.post('/tenants/'+ tenants.selected[0].id +'/create_duplicate.json?name='+ tenants.duplicate_name).success(function (data) {
      if (data.status) {
        notification.notify("Successfully Updated.", 1);
      } else {
        notification.notify(data.error_messages, 0);
      }
      ;
    }).error(notification.server_error);
  }

  var delete_tenant_data = function (id, action_type) {
    return $http.delete('/tenants/' + id + '.json?action_type=' + action_type).success(function (response) {
      if (response.status) {
        notification.notify("Successfully Updated.", 1);
      } else {
        notification.notify(response.error_messages, 0);
      }
      ;
    }).error(notification.server_error);
  };

  var rollback_single_tenant = function () {
    return $http.post("tenants/rollback.json", {single: single}).success(
      function (data) {
        if (data.status) {
          //notification.notify("Successfully Updated",1);
        } else {
          notification.notify(data.messages, 0);
        }
      }
    ).error(notification.server_error);
  };

  //Public facing API
  return {
    model: {
      get: get_default
    },
    setup: {
      update: update_setup
    },
    list: {
      get: get_list,
      total_tenants: total_tenants_list,
      select: select_list,
      update: update_list,
      update_node: update_list_node
    },
    single: {
      get: get_sinlge,
      select: select_single,
      update: update_access_restriction_data,
      delete: delete_tenant_data,
      rollback: rollback_single_tenant,
      duplicate: duplicate_tenant,
      popover: construct_popover
    }
  };
}]);
