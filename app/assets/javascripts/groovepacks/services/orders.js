groovepacks_services.factory('orders', ['$http', '$window', 'notification', '$q', function ($http, $window, notification, $q) {

  var success_messages = {
    update_status: "Status updated Successfully",
    delete: "Deleted Successfully",
    duplicate: "Duplicated Successfully"
  };

  var get_default = function () {
    return {
      list: [],
      selected: [],
      single: {},
      load_new: true,
      current: 0,
      setup: {
        sort: "",
        order: "DESC",
        filter: "awaiting",
        search: '',
        select_all: false,
        inverted: false,
        limit: 20,
        offset: 0,
        //used for updating only
        status: '',
        reallocate_inventory: false,
        orderArray: []
      },
      orders_count: {}
    };
  };

  //Setup related function
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

  var update_items_setup = function (items, type, value) {
    var ascending = true;
    var i = 0, length = items.length;
    while (i < items.length - 1) {
      if (items[i].category.toLowerCase() > items[++i].category.toLowerCase()) {
        ascending &= false;
        break;
      }
      ;
    }
    ;
    if (!ascending) {
      items.sort(sort_by_category_ascend);
    } else {
      items.sort(sort_by_category_descend);
    }
    ;
    return items;
  };

  var sort_by_category_ascend = function (a, b) {
    var aName = a.category.toLowerCase();
    var bName = b.category.toLowerCase();
    return ((aName < bName) ? -1 : ((aName > bName) ? 1 : 0));
  };

  var sort_by_category_descend = function (a, b) {
    var aName = a.category.toLowerCase();
    var bName = b.category.toLowerCase();
    return ((aName < bName) ? 1 : ((aName > bName) ? -1 : 0));
  };

  //list related functions
  var get_list = function (object, page) {
    var url = '';
    var setup = object.setup;
    if (typeof page != 'undefined' && page > 0) {
      page = page - 1;
    } else {
      page = 0;
    }
    object.setup.offset = page * object.setup.limit;
    if (setup.search == '') {
      url = '/orders.json?filter=' + setup.filter + '&sort=' + setup.sort + '&order=' + setup.order;
    } else {
      url = '/orders/search.json?search=' + setup.search + '&sort=' + setup.sort + '&order=' + setup.order;
    }
    url += '&limit=' + setup.limit + '&offset=' + setup.offset;
    return $http.get(url).success(
      function (data) {
        if (data.status) {
          object.load_new = (data.orders.length > 0);
          object.orders_count = data.orders_count;
          object.list = data.orders;
          object.current = false;
          if (object.setup.select_all) {
            object.selected = [];
          }
          for (var i = 0; i < object.list.length; i++) {
            if (object.single && typeof object.single['basicinfo'] != "undefined") {
              if (object.list[i].id == object.single.basicinfo.id) {
                object.current = i;
              }
            }
            if (object.setup.select_all) {
              object.list[i].checked = object.setup.select_all;
              select_single(object, object.list[i]);
            } else {
              for (var j = 0; j < object.selected.length; j++) {
                if (object.list[i].id == object.selected[j].id) {
                  object.list[i].checked = object.selected[j].checked;
                  break;
                }
              }
            }
          }
        } else {
          notification.notify("Can't load list of orders", 0);
        }
      }
    ).error(notification.server_error);
  };

  var generate_list = function (action, orders) {

    orders.setup.orderArray = [];
    for (var i = 0; i < orders.list.length; i++) {
      if (orders.list[i].checked == true) {
        orders.setup.orderArray.push({id: orders.list[i].id});
      }
    }
    var url = '';
    var myscope = {};
    var interval = null;
    //set url for each action.
    if (action == "pick_list") {
      url = '/orders/generate_pick_list.json';
    }
    else if (action == "packing_slip") {
      url = '/orders/generate_packing_slip.json';
    } else if (action == 'items_list') {
      url = '/orders/order_items_export.json';
    }

    //send post http request and catch the response to display the pdfs.
    return $http.post(url, orders.setup)
      .success(function (response) {
        if (action == "pick_list") {
          $window.open(response.data.pick_list_file_paths);
        } else if (action == 'items_list') {
          if (response['status']) {
            if (response.filename != '') {
              $window.open(response.filename);
            }
          } else {

            notification.notify(response['messages']);
          }
        }
      }).error(notification.server_error);


  };
  var cancel_pdf_gen = function (id) {
    return $http.post('/orders/cancel_packing_slip.json', {id: id}).success(function (data) {
      notification.notify(data['error_messages']);
      notification.notify(data['success_messages'], 1);
      notification.notify(data['notice_messages'], 2);
    }).error(notification.server_error);
  };

  var update_list = function (action, orders) {
    if (["update_status", "delete", "duplicate"].indexOf(action) != -1) {
      orders.setup.orderArray = [];
      for (var i = 0; i < orders.selected.length; i++) {
        if (orders.selected[i].checked == true) {
          orders.setup.orderArray.push({id: orders.selected[i].id});
        }
      }
      var url = '';
      if (action == "delete") {
        url = '/orders/delete_orders.json';
      } else if (action == "duplicate") {
        url = '/orders/duplicate_orders.json';
      } else if (action == "update_status") {
        url = '/orders/change_orders_status.json';
      }

      return $http.post(url, orders.setup).success(function (data) {
        orders.selected = [];
        if (data.status) {
          orders.setup.select_all = false;
          orders.setup.inverted = false;
          notification.notify(success_messages[action], 1);
          notification.notify(data.notice_messages, 2);
        } else {
          notification.notify(data.error_messages, 0);
        }
      }).error(notification.server_error);
    }
  };

  var update_list_by_option = function (option, orders) {
    orders.setup.orderArray = [];
    orders.setup.option = option;
    for (var i = 0; i < orders.selected.length; i++) {
      if (orders.selected[i].checked == true) {
        orders.setup.orderArray.push({id: orders.selected[i].id});
      }
    }

    return $http.post('/orders/changeorderstatus.json', orders.setup).success(function (data) {
      orders.selected = [];
      if (data.status) {
        orders.setup.select_all = false;
        orders.setup.inverted = false;
        notification.notify("order status updated successfully", 1);
        notification.notify(data.notice_messages, 2);
      } else {
        notification.notify(data.error_messages, 0);
      }
    }).error(notification.server_error);
  };

  var select_list = function (orders, from, to, state) {
    var url = '';
    var setup = orders.setup;
    var from_page = 0;
    var to_page = 0;

    if (typeof from.page != 'undefined' && from.page > 0) {
      from_page = from.page - 1;
    }
    if (typeof to.page != 'undefined' && to.page > 0) {
      to_page = to.page - 1;
    }
    var from_offset = from_page * setup.limit + from.index;
    var to_limit = to_page * setup.limit + to.index + 1 - from_offset;

    if (setup.search == '') {
      url = '/orders/getorders.json?filter=' + setup.filter + '&sort=' + setup.sort + '&order=' + setup.order;
    } else {
      url = '/orders/search.json?search=' + setup.search
    }
    url += '&is_kit=' + setup.is_kit + '&limit=' + to_limit + '&offset=' + from_offset;
    return $http.get(url).success(function (data) {
      if (data.status) {
        for (var i = 0; i < data.orders.length; i++) {
          data.orders[i].checked = state;
          select_single(orders, data.orders[i]);
        }
      } else {
        notification.notify("Some error occurred in loading the selection.");
      }
    });

  };


  var total_items_list = function (orders) {
    var total_items;
    if (orders.setup.search != "") {
      total_items = orders.orders_count['search'];
    } else {
      total_items = orders.orders_count[orders.setup['filter']];
    }
    if (typeof total_items == 'undefined') {
      total_items = 0;
    }
    return total_items;
  };

  var update_list_node = function (obj) {
    return $http.post('/orders/update_order_list.json', obj).success(function (data) {
      if (data.status) {
        notification.notify("Successfully Updated", 1);
      } else {
        notification.notify(data.error_msg, 0);
      }
    }).error(notification.server_error);
  };

  //single order related functions
  var get_single = function (id, orders) {
    return $http.get('/orders/' + id + '.json').success(function (data) {
      orders.single = {};
      if (data.order) {
        data.order.basicinfo.order_placed_time = new Date(data.order.basicinfo.order_placed_time);
        orders.single = data.order;
      }
    }).error(notification.server_error);
  };

  var update_single = function (orders, auto) {
    console.log(orders);
    if (typeof auto !== "boolean") {
      auto = true;
    }
    var order_data = {};
    for (var i in orders.single.basicinfo) {
      if (orders.single.basicinfo.hasOwnProperty(i) && i != 'id' && i != 'created_at' && i != 'updated_at') {
        order_data[i] = orders.single.basicinfo[i];
      }
    }
    console.log("order_data: ");
    console.log(order_data);
    return $http.put("orders/" + orders.single.basicinfo.id + ".json",{order: order_data}).success(
      function (data) {
        if (data.status) {
          if (!auto) {
            notification.notify("Successfully Updated", 1);
          }
        } else {
          notification.notify(data.messages, 0);
        }
      }
    ).error(notification.server_error);
  };

  var select_single = function (orders, row) {
    var found = false;
    for (var i = 0; i < orders.selected.length; i++) {
      if (orders.selected[i].id == row.id) {
        found = i;
        break;
      }
    }

    if (found !== false) {
      if (!row.checked) {
        orders.selected.splice(found, 1);
      }
    } else {
      if (row.checked) {
        orders.selected.push(row);
      }
    }
  };

  var rollback_single = function (single) {
    return $http.post("orders/rollback.json", {single: single}).success(
      function (data) {
        if (data.status) {
          //notification.notify("Successfully Updated",1);
        } else {
          notification.notify(data.messages, 0);
        }
      }
    ).error(notification.server_error);
  };
  var single_add_item = function (orders, ids) {
    return $http.post("orders/" + orders.single.basicinfo.id + "/add_item_to_order.json", {productids: ids, qty: 1}).success(
      function (data) {
        if (data.status) {
          notification.notify("Item Successfully Added", 1);
        } else {
          notification.notify("Error adding", 0);
        }
      }
    ).error(notification.server_error);
  };

  var single_remove_item = function (ids) {
    return $http.post("orders/remove_item_from_order.json", {orderitem: ids}).success(
      function (data) {
        if (data.status) {
          notification.notify("Item Successfully Removed", 1);
        } else {
          notification.notify(data.messages, 0);
        }
      }
    ).error(notification.server_error);
  };

  var single_record_exception = function (orders) {
    return $http.post(
      '/orders/'+orders.single.basicinfo.id+'/record_exception.json',
      {
        reason: orders.single.exception.reason,
        description: orders.single.exception.description,
        assoc: orders.single.exception.assoc
      }
    ).success(function (data) {
        if (data.status) {
          notification.notify("Exception successfully recorded", 1);
        } else {
          notification.notify(data.messages, 0);
        }
      }).error(notification.server_error);
  };

  var single_clear_exception = function (orders) {
    return $http.post('/orders/'+orders.single.basicinfo.id+'/clear_exception.json').success(function (data) {
      if (data.status) {
        notification.notify("Exception successfully cleared", 1);
      } else {
        notification.notify(data.messages, 0);
      }
    }).error(notification.server_error);
  };

  var single_update_item_qty = function (item) {
    return $http.post('/orders/update_item_in_order.json', {orderitem: item.id, qty: item.qty}).success(function (data) {
      if (data.status) {
        notification.notify("Item updated", 1);
      } else {
        notification.notify(data.messages, 0);
      }
    }).error(notification.server_error);
  };

  var single_update_print_status = function (item) {
    var result = $q.defer();
    return $http.post('/orders/update_item_in_order.json', {orderitem: item.id}).success(function (data) {
      if (data.status) {
        if (data.messages.length > 0) {
          alert(data.messages[0]);
          result.resolve();
        }
        ;
      } else {
        notification.notify(data.messages, 0);
      }
    }).error(notification.server_error);
    return result.promise;
  };

  var single_print_barcode = function (item) {
    $window.open('/products/' + item.id + '/generate_barcode_slip.pdf');
  };

  var acknowledge_activity = function (activity_id) {
    return $http.post('/order_activities/acknowledge/' + activity_id, null).success(function (data) {
      if (data.status) {
        notification.notify("Activity Acknowledged.", 1);
      } else {
        notification.notify(data.messages, 0);
      }
    }).error(notification.server_error);
  };

  return {
    model: {
      get: get_default
    },
    setup: {
      update: update_setup,
      update_items: update_items_setup
    },
    list: {
      get: get_list,
      update: update_list,
      select: select_list,
      total_items: total_items_list,
      update_node: update_list_node,
      generate: generate_list,
      cancel_pdf_gen: cancel_pdf_gen,
      update_with_option: update_list_by_option
    },
    single: {
      get: get_single,
      update: update_single,
      select: select_single,
      rollback: rollback_single,
      item: {
        add: single_add_item,
        remove: single_remove_item,
        update: single_update_item_qty,
        print_status: single_update_print_status,
        print_barcode: single_print_barcode
      },
      exception: {
        record: single_record_exception,
        clear: single_clear_exception
      },
      activity: {
        acknowledge: acknowledge_activity
      }
    }
  }
}]);
