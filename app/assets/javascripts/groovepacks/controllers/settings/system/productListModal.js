groovepacks_controllers.
  controller('productListModal', ['$scope', 'context_data', '$state', '$stateParams', '$modal', '$modalInstance', '$timeout', 'products', '$q', 'notification',
    function (scope, context_data, $state, $stateParams, $modal, $modalInstance, $timeout, products, $q, notification) {

      var myscope = {};

      /**
       * Public methods
       */

      scope.ok = function () {
        $modalInstance.close("ok-button-click");
      };

      scope.cancel = function () {
        $modalInstance.dismiss("cancel-button-click");
      };

      myscope.update = function (reason) {
        if (reason == "cancel-button-click") {
          myscope.rollback();
        } else if (typeof scope.warehouses.single.inv_wh_info.id != "undefined") {
          scope.update_single_warehouse(false);
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
            scope.paginate.current_page = page;
            scope.paginate.show = true;
            scope._can_load_products = true;
          });
        } else {
          myscope.do_load_products = true;
          var req = $q.defer();
          req.resolve();
          return req.promise;
        }
      };

      scope.set_all = function (value) {
        scope.products.setup.select_all = true;
        scope.products.setup.status = value;
        products.list.update('update_per_product', scope.products).then(function () {
          scope.products.setup.status = '';
          myscope.get_products();
        });
      };

      scope.set_one = function (product, value) {
        products.list.update_node({
          id: product.id,
          var: scope.products.setup.setting,
          value: value
        }).then(function () {
          myscope.get_products();
        });
      };
      myscope.search_products = function () {
        myscope.get_products(1);
      };


      scope.handlesort = function (predicate) {
        myscope.common_setup_opt('sort', predicate, 'product');
      };
      myscope.common_setup_opt = function (type, value, selector) {
        products.setup.update(scope.products.setup, type, value);
        myscope.get_products();
      };
      myscope.can_do_load_products = function () {
        if (scope._can_load_products && myscope.do_load_products) {
          myscope.get_products();
          myscope.do_load_products = false;
        }
      };
      /**
       * private properties
       */

      myscope.init = function () {
        scope.products = products.model.get();
        scope.products.setup.limit = 30;
        scope.products.setup.filter = "all";
        scope.products.setup.is_kit = -1;
        scope.products.setup.sort = 'sku';
        scope.products.setup.order = 'ASC';
        scope.context = context_data;
        scope.products.setup.setting = scope.context.type;

        //All tabs
        myscope.do_load_products = false;
        scope._can_load_products = true;
        scope.paginate = {
          show: false,
          //send a large number to prevent resetting page number
          total_items: 50000,
          max_size: 12,
          current_page: 1,
          items_per_page: scope.products.setup.limit
        };
        /**
         * Public properties
         */

        myscope.get_products();
        $timeout(scope.focus_search, 200);
        scope.$watch('products.setup.search', myscope.search_products);
        scope.$watch('_can_load_products', myscope.can_do_load_products);
        scope.$watch('paginate.current_page', myscope.get_products);
      };

      myscope.init();
    }]);
