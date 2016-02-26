groovepacks_controllers.
  controller('scanPackProductEditCtrl', ['$scope', '$http', '$timeout', '$stateParams', '$location', '$state', '$cookies', 'products', 'scanPack',
    function ($scope, $http, $timeout, $stateParams, $location, $state, $cookies, products, scanPack) {

      $scope.editreload = function () {
        return $scope.rfpinit().then(function () {
          $scope.set('title', "Fix item statuses or scan a new order");
          if (typeof $scope.data.raw.data != "undefined"
            && typeof $scope.data.raw.data.inactive_or_new_products != "undefined"
            && $scope.data.raw.data.inactive_or_new_products.length > 0) {
            $scope.products.list = $scope.data.raw.data.inactive_or_new_products;
            $state.go('scanpack.rfp.product_edit', {order_num: $stateParams.order_num});
          } else if ($scope.data.order.status != 'onhold') {
            $state.go('scanpack.rfp.default', {order_num: $stateParams.order_num});
          } else {
            $scope.notify("No Inactive products found. Please try again");
            $state.go('scanpack.rfo');
          }
        });
      };

      $scope.update_product_list = function (product, prop) {
        if(!product[prop] /*if null*/){return}
        products.list.update_node({
          id: product.id,
          var: prop,
          value: product[prop]
        }).then(function () {
          $scope.set('order', {});
          $scope.editreload();
        });
      };

      $scope.editinit = function () {
        $scope.products = products.model.get();
        $scope.gridOptions = {
          identifier: 'scanpackinactiveornew',
          setup: $scope.products.setup,
          data: {order_num: $stateParams.order_num},
          editable: {
            array: false,
            update: $scope.update_product_list,
            elements: {
              status: {
                type: 'select',
                options: [
                  {name: "Active", value: 'active'},
                  {name: "Inactive", value: 'inactive'},
                  {name: "New", value: 'new'}
                ]
              }
            }
          },
          all_fields: {
            image: {
              name: "Image",
              editable: false,
              transclude: '<div ng-click="options.editable.functions.name(row,$event)" class="pointer single-image"><img class="img-responsive" ng-src="{{row.product_images[0].image}}" /></div>'
            },
            name: {
              name: "Item Name",
              transclude: '<a ui-sref="scanpack.rfp.product_edit.single({order_num: options.data.order_num, product_id: row.id })" >{{row[field]}}</a>',
              editable: false
            },
            status: {
              name: "Status"
            },
            sku: {
              name: "SKU"
            },
            barcode: {
              name: "Barcode"
            }
          }
        };
        return $scope.editreload();
      };


      $scope.product_modal_closed_callback = function () {
        $scope.set('order', {});
        $scope.editreload();
      };

      $scope.editinit();
    }]);
