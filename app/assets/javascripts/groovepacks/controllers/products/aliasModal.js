groovepacks_controllers.controller('aliasModal', ['$scope', 'type', 'exceptions', 'id', '$timeout', '$modalInstance', '$q', 'notification', 'products',
  function (scope, type, exceptions, id, $timeout, $modalInstance, $q, notification, products) {

    var myscope = {};
    //Definitions
    scope.ok = function () {
      $modalInstance.close({selected: scope.selected_aliases});
    };
    scope.cancel = function () {
      $modalInstance.dismiss();
    };
    /*
     * Public methods
     */

    //Setup options
    scope.handlesort = function (predicate) {
      myscope.common_setup_opt('sort', predicate, 'product');
    };

    /*
     * Private methods
     */

    scope.add_alias_product = function (product) {
      product.checked = !product.checked;
      if (scope.is_kit || scope.is_order || type == 'master_alias') {
        if (product.checked) {
          scope.selected_aliases.push(product.id);
        } else {
          scope.selected_aliases.splice(scope.selected_aliases.indexOf(product.id), 1);
        }
      } else {
        if (confirm("Are you sure? This can not be undone!")) {
          scope.selected_aliases.push(product.id);
          scope.ok();
        }
      }
    };

    myscope.get_products = function (page) {
      if (typeof page == 'undefined') {
        page = scope.paginate.current_page;
      }
      if (scope._can_load_products) {
        scope._can_load_products = false;
        return products.list.get(scope.products, page).success(function (response) {
          scope.paginate.total_items = products.list.total_items(scope.products);
          scope.paginate.show = true;
          var tmp_list = scope.products.list;
          scope.products.list = [];
          for (var i = 0; i < tmp_list.length; i++) {
            if (myscope.exceptions.indexOf(tmp_list[i].id) == -1) {
              if (scope.selected_aliases.indexOf(tmp_list[i].id) != -1) {
                tmp_list[i].checked = true
              }
              scope.products.list.push(tmp_list[i]);
            }
          }
          scope._can_load_products = true;
        });
      } else {
        myscope.do_load_products = true;
        var req = $q.defer();
        req.resolve();
        return req.promise;
      }
    };

    myscope.common_setup_opt = function (type, value, selector) {
      products.setup.update(scope.products.setup, type, value);
      scope.products.setup.is_kit = (selector == 'kit') ? 1 : 0;
      scope.products.setup.is_kit = scope.is_order ? -1 : scope.products.setup.is_kit;
      myscope.get_products(1);
    };


    //Watcher ones
    myscope.can_do_load_products = function () {
      if (scope._can_load_products && myscope.do_load_products) {
        myscope.get_products(1);
        myscope.do_load_products = false;
      }
    };

    myscope.search_products = function () {
      myscope.get_products(1);
    };

    //Constructor
    myscope.init = function () {
      //Public properties
      scope.products = products.model.get();
      scope.products.setup.limit = 30;
      scope.products.setup.filter = "all";
      scope.custom_identifier = Math.floor(Math.random() * 1000);
      scope.is_kit = false;
      scope.is_order = false;
      scope.selected_aliases = [];
      scope.load_disabled = false;

      //Private properties

      myscope.exceptions = [];
      myscope.do_load_products = false;
      scope._can_load_products = true;
      myscope.accepted_types = ['alias', 'kit', 'order', 'master_alias'];
      scope.paginate = {
        show: false,
        //send a large number to prevent resetting page number
        total_items: 50000,
        max_size: 12,
        current_page: 1,
        items_per_page: scope.products.setup.limit
      };
      //$("#alias-search-query-"+scope.custom_identifier).focus();
      //Register watchers

      if (myscope.accepted_types.indexOf(type) == -1) {
        type = 'alias';
      }
      myscope.exceptions = [];
      scope.is_order = (type == 'order');
      scope.is_kit = (type == 'kit');
      scope.products.setup.is_kit = (scope.is_order || type == 'alias' || type == 'master_alias') ? -1 : scope.products.setup.is_kit;
      if (typeof exceptions != 'undefined') {
        for (var i = 0; i < exceptions.length; i++) {
          myscope.exceptions.push(exceptions[i].id);
        }
      }
      if (typeof id !== 'undefined') {
        myscope.exceptions.push(id);
      }
      myscope.get_products(1);
      $timeout(scope.focus_search, 200);
      scope.$watch('products.setup.search', myscope.search_products);
      scope.$watch('_can_load_products', myscope.can_do_load_products);
      scope.$watch('paginate.current_page', myscope.get_products);
    };

    //Definitions end above this line
    /*
     * Initialization
     */
    myscope.init();
  }
]);
