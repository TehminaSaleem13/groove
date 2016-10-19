groovepacks_controllers.
  controller('scanPackProductEditCtrl', ['$scope', '$http', '$timeout', '$stateParams', '$location', '$state', '$cookies', '$modal', 'products', 'scanPack', 'orders',
    function ($scope, $http, $timeout, $stateParams, $location, $state, $cookies, $modal, products, scanPack, orders) {

      $scope.editreload = function () {
        return $scope.rfpinit().then(function () {
          $scope.set('title', "Fix item statuses or scan a new order");
          $scope.set('msg', "Not sure how to proceed? Click Here");
          if (typeof $scope.data.raw.data != "undefined"
            && typeof $scope.data.raw.data.inactive_or_new_products != "undefined"
            && $scope.data.raw.data.inactive_or_new_products.length > 0) {

            $scope.products.list = $scope.data.raw.data.inactive_or_new_products;
            $state.go('scanpack.rfp.product_edit', {order_num: $stateParams.order_num});
            if (typeof $scope.data.raw.data.zero_qty_product != "undefined") {
              $scope.order_details($scope.data.order.id);
            }

          } else if ($scope.data.order.status != 'onhold') {
            $state.go('scanpack.rfp.default', {order_num: $stateParams.order_num});
          } else {
            $scope.notify("No Inactive products found. Please try again");
            $state.go('scanpack.rfo');
          }
        });
      };

      $scope.order_details = function (id) {
        if ($scope.current_user.can('add_edit_orders')) {
          var item_modal = $modal.open({
            templateUrl: '/assets/views/modals/order/main.html',
            controller: 'ordersSingleModal',
            size: 'lg',
            resolve: {
              order_data: function () {
                return orders.model.get()
              },
              load_page: function () {
                return function () {
                  var req = $q.defer();
                  req.reject();
                  return req.promise;
                }
              },
              order_id: function () {
                return id;
              }
            }
          });
          item_modal.result.then(
            //Get triggers when modal is closed
            function () {
              $scope.set('order', {});
              $scope.editreload();
            },
            //gets triggers when modal is dismissed.
            function () {
              $scope.set('order', {});
              $scope.editreload();
            }
          );
        }
      };

      $scope.update_product_list = function (product, prop) {
        if(prop == 'barcode' && !product[prop] && product['status'] != 'active' /*if null*/){return}
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
          dynamic_width: true,
          identifier: 'scanpackinactiveornew',
          setup: $scope.products.setup,
          scrollbar: false,
          no_of_lines: 3,
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
              col_length: 30,
              transclude: '<a ui-sref="scanpack.rfp.product_edit.single({order_num: options.data.order_num, product_id: row.id })" style="text-decoration: none" tooltip=\'{{row[field].length ? row[field].chunk(25).join(" ") : ("Edit" + field)}}\'>{{row[field] | cut:false:(25*options.no_of_lines)}}</a>'
            },
            status: {
              name: "Status",
              col_length: 8,
              transclude: "<span class='label label-default' ng-class=\"{" +
                "'label-success': row[field] == 'active', " +
                "'label-info': row[field] == 'new' }\">" +
                "{{row[field]}}</span>"
            },
            sku: {
              name: "SKU",
              col_length: 30
            },
            barcode: {
              name: "Barcode",
              col_length: 30
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
