groovepacks_services.factory('products', ['$http', 'notification', 'editable', '$window', function ($http, notification, editable, $window) {

  var success_messages = {
    update_status: "Status Update Queued Successfully",
    delete: "Delete Queued Successfully",
    duplicate: "Duplicate Queued Successfully",
    barcode: "Barcodes generated Successfully",
    receiving_label: "Labels generated Successfully",
    update_per_product: "Updated Successfully"
  };

  //default object
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
        filter: "active",
        search: '',
        select_all: false,
        inverted: false,
        is_kit: 0,
        limit: 20,
        offset: 0,
        //for per product setting only
        setting: '',
        //used for updating only
        status: '',
        productArray: []
      },
      products_count: {}
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
      url = '/products.json?filter=' + setup.filter + '&sort=' + setup.sort + '&order=' + setup.order;
    } else {
      url = '/products/search.json?search=' + setup.search + '&sort=' + setup.sort + '&order=' + setup.order;
    }
    url += '&is_kit=' + setup.is_kit + '&limit=' + setup.limit + '&offset=' + setup.offset;
    return $http.get(url).success(
      function (data) {
        if (data.status) {
          object.load_new = (data.products.length > 0);
          object.products_count = data.products_count;
          object.list = data.products;
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
          notification.notify("Can't load list of products", 0);
        }
      }
    ).error(notification.server_error);
  };

  var total_items_list = function (products) {
    var total_items;
    if (products.setup.search != "") {
      total_items = products.products_count['search'];
    } else {
      total_items = products.products_count[products.setup['filter']];
    }
    if (typeof total_items == 'undefined') {
      total_items = 0;
    }
    return total_items;
  };

  var select_notification = function () {
    notification.notify("Please select atleast one product", 0);
  }

  var update_list = function (action, products) {
    if (['update_status', 'delete', 'duplicate', 'barcode', 'receiving_label', 'update_per_product'].indexOf(action) != -1) {
      products.setup.productArray = [];
      for (var i = 0; i < products.selected.length; i++) {
        if (products.selected[i].checked == true) {
          products.setup.productArray.push({id: products.selected[i].id});
        }
      }
      var url = '';
      if (action == "delete") {
        url = '/products/delete_product.json';
      } else if (action == "duplicate") {
        url = '/products/duplicate_product.json';
      } else if (action == "update_status") {
        url = '/products/change_product_status.json';
      } else if (action == "barcode") {
        url = '/products/generate_barcode.json';
      } else if (action == "receiving_label") {
        url = '/products/print_receiving_label.json';
      } else if (action == 'update_per_product') {
        url = '/products/scan_per_product.json';
      }

      return $http.post(url, products.setup).success(function (data) {
        if (data.status) {
          notification.notify(success_messages[action], 1);
          products.setup.select_all = false;
          products.setup.inverted = false;
          products.selected = [];
          if (action == "receiving_label") {
            $window.open(data.receiving_label_path);
          }
        } else {
          notification.notify(data.messages, 0);
        }
      }).error(notification.server_error);
    }
  };

  var generate_csv = function (products) {
    products.setup.productArray = [];
    for (var i = 0; i < products.selected.length; i++) {
      if (products.selected[i].checked == true) {
        products.setup.productArray.push({id: products.selected[i].id});
      }
    }
    return $http.post('/products/generate_products_csv', products.setup).success(function (data) {
      if (data.status) {
        products.setup.select_all = false;
        products.setup.inverted = false;
        products.selected = [];
        $window.open('/csv/' + data.filename);
      } else {
        notification.notify(data.messages, 0);
      }
      ;
    });
  };

  var select_list = function (products, from, to, state) {
    var url = '';
    var setup = products.setup;
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
      url = '/products.json?filter=' + setup.filter + '&sort=' + setup.sort + '&order=' + setup.order;
    } else {
      url = '/products/search.json?search=' + setup.search;
    }
    url += '&is_kit=' + setup.is_kit + '&limit=' + to_limit + '&offset=' + from_offset;
    return $http.get(url).success(function (data) {
      if (data.status) {
        for (var i = 0; i < data.products.length; i++) {
          data.products[i].checked = state;
          select_single(products, data.products[i]);
        }
      } else {
        notification.notify("Some error occurred in loading the selection.");
      }
    });

  };

  var update_list_node = function (obj) {
    return $http.post('/products/update_product_list.json', obj).success(function (data) {
      if (data.status) {
        notification.notify("Successfully Updated", 1);
      } else {
        notification.notify(data.messages, 0);
      }
    }).error(notification.server_error);
  };

  var basicinfo_changed = function (basicinfo, data) {
    var result = true;
    for (var key in basicinfo) {
      if (key == 'status' || key == 'created_at' || key == 'updated_at') {
        continue;
      } else if (basicinfo[key] != data[key]) {
        result = false;
        break;
      };
    };
    return result;
  };

  //single product related functions
  var get_single = function (id, products, auto) {
    return $http.get('/products/' + id + '.json').success(function (data) {
      if (data.product) {
        if (!auto) {
          if (basicinfo_changed(products.single['basicinfo'], data.product.basicinfo) &&
            products.single['barcodes'].length == data.product.barcodes.length &&
            products.single['cats'].length == data.product.cats.length &&
            products.single['inventory_warehouses'].length == data.product.inventory_warehouses.length &&
            products.single['skus'].length == data.product.skus.length) {
            products.signle = {};
            products.single = data.product;
          }
        }else {
          if (typeof products.single['basicinfo'] != "undefined" && data.product.basicinfo.id == products.single.basicinfo.id) {
            angular.extend(products.single, data.product);
          }else {
            products.single = {};
            products.single = data.product;
          };
        };
      } else {
        products.single = {};
      };
    }).error(notification.server_error).success(editable.force_exit).error(editable.force_exit);
  };

  //single product retrieval by barcode
  var get_single_product_by_barcode = function (barcode, products) {
    return $http.get('/products/'+null+'.json?barcode=' + barcode).success(function (data) {
      products.single = {};
      if (data.product) {
        products.single = data.product;
      }
      else {
        notification.notify('Cannot find product with barcode: ' + barcode, 0);
      }
    }).error(notification.server_error);
  };

  var create_single = function (products) {
    return $http.post('/products').success(function (data) {
      products.single = {};
      if (!data.status) {
        notification.notify(data.messages, 0);
      }
    }).error(notification.server_error);
  };

  var update_sync_options = function (products) {
    return $http.put('/products/'+products.single.basicinfo.id+'/sync_with.json', products.single.sync_option).success(function (data) {
      if (!data.status) {
        notification.notify(data.messages, 0);
      }
    }).error(notification.server_error);
  };

  var update_single = function (products, auto) {
    if (typeof auto !== "boolean") {
      auto = true;
    }
    return $http.put('/products/'+products.single.basicinfo.id+'.json', products.single).success(function (data) {
      if (data.status) {
        if (!auto) {
          notification.notify("Successfully Updated", 1);
        }
      } else {
        if (data.message) {
          notification.notify(data.message, 0);
        } else {
          notification.notify("Some error Occurred", 0);
        }
      }
    }).error(notification.server_error);
  };

  var select_single = function (products, row) {
    var found = false;
    for (var i = 0; i < products.selected.length; i++) {
      if (products.selected[i].id == row.id) {
        found = i;
        break;
      }
    }

    if (found !== false) {
      if (!row.checked) {
        products.selected.splice(found, 1);
      }
    } else {
      if (row.checked) {
        products.selected.push(row);
      }
    }
  };

  var add_image = function (products, image) {
    return $http({
      method: 'POST',
      headers: {'Content-Type': undefined},
      url: '/products/'+products.single.basicinfo.id+'/add_image.json',
      transformRequest: function (data) {
        var request = new FormData();
        for (var key in data) {
          request.append(key, data[key]);
        }
        return request;
      },
      data: {product_image: image.file}
    }).success(function (data) {
      if (data.status) {
        notification.notify("Successfully Updated", 1);

      } else {
        notification.notify("Some error Occurred", 0);
      }

    }).error(notification.server_error);
  };

  var update_image_data = function (image) {
    return $http.post("products/update_image.json", {image: image}).success(
      function (data) {
        if (data.status) {
          notification.notify("Successfully Updated", 1);
        } else {
          notification.notify("Some error occurred", 0);
        }
        ;
      }
    ).error(notification.server_error);
  };

  var set_alias = function (products, ids) {
    return $http.post("products/"+ids[0]+"/set_alias.json", {
      product_alias_ids: [products.single.basicinfo.id]
    }).success(
      function (data) {
        if (data.status) {
          notification.notify("Successfully Updated", 1);
        } else {
          notification.notify("Some error Occurred", 0);
        }
      }
    ).error(notification.server_error);
  };
  var master_alias = function (products, selected) {
    return $http.post("products/"+products.single.basicinfo.id+"/set_alias.json", {
      product_alias_ids: selected
    }).success(
      function (data) {
        if (data.status) {
          notification.notify("Successfully Updated", 1);
        } else {
          notification.notify("Some error Occurred", 0);
        }
      }
    ).error(notification.server_error);
  };

  var add_to_kit = function (kits, ids) {
    return $http.post("/products/"+kits.single.basicinfo.id+"/add_product_to_kit.json", {product_ids: ids}).success(
      function (data) {
        if (data.status) {
          notification.notify("Successfully Added", 1);
        } else {
          notification.notify(data.messages, 0);
        }
      }
    ).error(notification.server_error);
  };

  var remove_from_kit = function (products, skus) {
    return $http.post('/products/'+products.single.basicinfo.id+'/remove_products_from_kit.json', {
      kit_products: skus
    }).success(function (data) {
      if (data.status) {
        notification.notify("Successfully Removed", 1);
      } else {
        notification.notify(data.messages, 0);
      }
    }).error(notification.server_error);
  };

  var reset_single_obj = function (products) {
    products.single = {};
  };

  var acknowledge_activity = function (activity_id) {
    return $http.put('/product_kit_activities/' + activity_id + '/acknowledge/', null).success(function (data) {
      if (data.status) {
        notification.notify("Activity Acknowledged.", 1);
      } else {
        notification.notify(data.messages, 0);
      }
    }).error(notification.server_error);
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
      total_items: total_items_list,
      update: update_list,
      select: select_list,
      update_node: update_list_node,
      generate: generate_csv,
      select_notification: select_notification
    },
    single: {
      get: get_single,
      get_by_barcode: get_single_product_by_barcode,
      create: create_single,
      update: update_single,
      update_sync_options: update_sync_options,
      select: select_single,
      image_upload: add_image,
      update_image: update_image_data,
      alias: set_alias,
      master_alias: master_alias,
      reset_obj: reset_single_obj,
      kit: {
        add: add_to_kit,
        remove: remove_from_kit
      },
      activity: {
        acknowledge: acknowledge_activity
      }
    }
  };
}]);
