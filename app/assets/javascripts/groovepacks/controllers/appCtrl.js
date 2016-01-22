groovepacks_controllers.
  controller('appCtrl', ['$rootScope', '$scope', '$timeout', '$modalStack', '$state', '$filter', '$document', '$window', 'hotkeys', 'auth', 'notification', 'importOrders', 'groovIO', 'editable', 'stores',
    function ($rootScope, $scope, $timeout, $modalStack, $state, $filter, $document, $window, hotkeys, auth, notification, importOrders, groovIO, editable, stores) {
      $scope.import_store_id = null;

      $scope.$on("user-data-reloaded", function () {
        $scope.current_user = auth;
      });

      groovIO.on('import_status_update', function (message) {

        if (typeof(message) != 'undefined') {
          //console.log("socket",message);
          $scope.import_summary = angular.copy(message);
          $scope.import_groov_popover = {title: '', content: '', data: []};
          var get_import_type = function () {
            if ($scope.import_summary.import_info.import_summary_type == 'update_locations') {
              return ("Update");
            } else {
              return ("Import");
            }
          }

          var get_import_type_past = function () {
            if ($scope.import_summary.import_info.import_summary_type == 'update_locations') {
              return ("Updated");
            } else {
              return ("Imported");
            }
          }
          if ($scope.import_summary.import_info.status == 'completed') {
            $scope.import_groov_popover.title = 'Last ' + get_import_type() + ': ' +
              $filter('date')($scope.import_summary.import_info.updated_at,
                'EEE MM/dd/yy hh:mm a');
          } else if ($scope.import_summary.import_info.status == 'in_progress') {
            $scope.import_groov_popover.title = get_import_type() + ' in Progress';
          } else if ($scope.import_summary.import_info.status == 'not_started') {
            $scope.import_groov_popover.title = get_import_type() + ' not started';
          } else if ($scope.import_summary.import_info.status == 'cancelled') {
            $scope.import_groov_popover.title = get_import_type() + ' cancelled';
          }

          var logos = {
            Ebay: {
              alt: "Ebay",
              src: "https://s3.amazonaws.com/groovepacker/EBAY-BUTTON.png"
            },
            Amazon: {
              alt: "Amazon",
              src: "https://s3.amazonaws.com/groovepacker/amazonLogo.jpg"
            },
            Magento: {
              alt: "Magento",
              src: "https://s3.amazonaws.com/groovepacker/MagentoLogo.jpg"
            },
            Magento2: {
              alt: "Magento API 2",
              src: "https://s3.amazonaws.com/groovepacker/MagentoLogo.jpg"
            },
            Shipstation: {
              alt: "ShipStation",
              src: "/assets/images/ShipStation_logo.png"
            },
            "Shipstation API 2": {
              alt: "ShipStation",
              src: "/assets/images/ShipStation_logo.png"
            },
            Shipworks: {
              alt: "ShipWorks",
              src: "/assets/images/shipworks_logo.png"
            },
            CSV: {
              alt: "CSV",
              src: "/assets/images/csv_logo.png"
            },
            Shopify: {
              alt: "CSV",
              src: "/assets/images/shopify_import.png"
            },
            "BigCommerce": {
              alt: "BigCommerce",
              src: "/assets/images/bigcommerce-logo.png"
            },
            "ShippingEasy": {
              alt: "ShippingEasy",
              src: "/assets/images/shipping_easy.png"
            }

          };
          for (var i = 0; i < $scope.import_summary.import_items.length; i++) {
            var import_item = $scope.import_summary.import_items[i];
            if (import_item && import_item.store_info) {
              var single_data = {progress: {}, progress_product: {}, name: ''};
              single_data.logo = logos[import_item.store_info.store_type];
              single_data.name = import_item.store_info.name;
              single_data.id = import_item.store_info.id;
              single_data.store_type = import_item.store_info.store_type;
              single_data.status = import_item.store_info.status;
              single_data.progress.type = import_item.import_info.status;
              single_data.progress.value = 0;
              single_data.progress.message = '';
              single_data.progress_product.show = false;
              single_data.progress_product.value = 0;
              single_data.progress_product.message = '';
              single_data.progress_product.type = 'in_progress';

              if (import_item.import_info.status == 'completed' || import_item.import_info.status == 'cancelled') {
                single_data.progress.value = 100;
                if (import_item.store_info.store_type == 'Shipworks' || import_item.store_info.store_type == 'CSV') {
                  single_data.progress.message += 'Last ' + get_import_type_past() + ' Order #' + import_item.import_info.current_increment_id + ' at ' + $filter('date')(import_item.import_info.updated_at, 'dd MMM hh:mm a');
                } else if (import_item.import_info.success_imported <= 0) {
                  if ($scope.import_summary.import_info.import_summary_type == 'update_locations') {
                    single_data.progress.message += ' No updates made. Locations are upto date.';
                  } else {
                    single_data.progress.message += ' No new orders found.';
                  }
                } else {
                  if ($scope.import_summary.import_info.import_summary_type == 'update_locations') {
                    single_data.progress.message += import_item.import_info.success_imported + ' Orders were updated.'
                  } else {
                    single_data.progress.message += import_item.import_info.success_imported + ' New Orders Imported.';
                  }
                }
                if (import_item.import_info.status == 'cancelled') {
                  single_data.progress.message += ' The import was cancelled.';
                }
              } else if (import_item.import_info.status == 'not_started') {
                single_data.progress.message += get_import_type() + ' not started.';
              } else if (import_item.import_info.status == 'in_progress') {
                $scope.import_summary.import_info.status = 'in_progress';
                if (import_item.import_info.to_import > 0) {
                  single_data.progress.value = (((import_item.import_info.success_imported + import_item.import_info.previous_imported) / import_item.import_info.to_import) * 100);
                  single_data.progress.message += get_import_type_past() + ' ' +
                    (import_item.import_info.success_imported + import_item.import_info.previous_imported) + '/' + import_item.import_info.to_import + ' Orders ';
                  if (import_item.import_info.current_increment_id != '') {
                    single_data.progress.message += 'Current #' + import_item.import_info.current_increment_id + ' ';
                  }
                  single_data.progress_product.show = true;
                  if (import_item.import_info.current_order_items > 0) {
                    single_data.progress_product.value = (import_item.import_info.current_order_imported_item / import_item.import_info.current_order_items) * 100;
                    single_data.progress_product.message += get_import_type_past() + ' ' +
                      import_item.import_info.current_order_imported_item + '/' + import_item.import_info.current_order_items + ' Products';
                  } else {
                    single_data.progress_product.value = 0;
                  }
                  if (single_data.progress_product.value == 0) {
                    if (import_item.import_info.current_order_items <= 0) {
                      single_data.progress_product.type = 'not_started';
                      single_data.progress_product.message = 'waiting on source...';
                    }
                  } else if (single_data.progress_product.value == 100) {
                    single_data.progress_product.type = 'completed';
                  }
                } else {
                  single_data.progress.message += get_import_type() + ' in progress.';
                }
              } else if (import_item.import_info.status == 'failed') {
                single_data.progress.value = 100;
                if (import_item.import_info.message != '') {
                  single_data.progress.message = import_item.import_info.message;
                }
              } else if (import_item.import_info.status == 'cancelled') {
                single_data.progress.value = 100;
              } else {
                single_data.progress.value = 100;
                single_data.progress.type = 'completed';
                if (import_item.import_info.message != '') {
                  single_data.progress.message = import_item.import_info.message;
                }
              }
              $scope.import_groov_popover.data.push(single_data);
            }
          }
          $scope.import_groov_popover.content =
            '<table style="font-size: 12px;width:100%;">' +
              '<tr>' +
                '<td>' +
                  '<span class="place_select" style="display: none;">' +
                    '<div class="col-lg-2 col-md-2" style="position: absolute; top: 5px; right: 0px;" dropdown>' +
                      '<button type="button" class="groove-button dropdown-toggle days_select" data-toggle="dropdown" style="float:rifght;">' +
                        'Days <span class="caret"></span>' +
                      '</button>' +
                      '<ul class="dropdown-menu" role="menu">' +
                        '<li ng-repeat="day in [1,2,3,4,5,6,7,8,9,10]">' +
                          '<a ng-click="issue_import(import_store_id, day, \'deep\')">{{day}}</a>' +
                        '</li>' +
                      '</ul>' +
                    '</div>' +
                  '</span>' +
                '</td>' +
              '</tr>' +
              '<tr ng-repeat="store in import_groov_popover.data" ng-hide="!store.status">' +
                '<td width="60px;" style="white-space: nowrap;">' +
                  '<a class="btn" href="#/settings/stores/{{store.id}}"><img ng-src="{{store.logo.src}}" width="60px" alt="{{store.logo.alt}}"/></a>' +
                '</td>' +
                '<td style="white-space: nowrap;">{{store.name}}</td>' +
                '<td style="width:62%;padding:3px;">' +
                  '<progressbar type="{{store.progress.type}}" value="store.progress.value"> {{store.progress.message| limitTo: 75}}</progressbar>' +
                  '<progressbar ng-show="store.progress_product.show" type="{{store.progress_product.type}}" value="store.progress_product.value">{{store.progress_product.message | limitTo: 56}}</progressbar>' +
                '</td>' +
                '<td style="text-align:right;width:38%;padding:3px;">' +
                  '<div class="btn-group">' +
                    '<span ng-show="store.store_type==\'BigCommerce\'">' +
                      '<a class="btn BigCommerce" ng-hide="import_summary.import_info.status==\'in_progress\'" title="Deep Import" ng-click="issue_import(store.id, 4, \'deep\')"><img class="icons" src="/assets/images/deep_import.png"></img></a>' +
                    '</span>' +
                    '<span ng-show="store.store_type==\'ShippingEasy\'">' +
                      '<a class="btn ShippingEasy" ng-hide="import_summary.import_info.status==\'in_progress\'" title="Deep Import" ng-click="open_popup(store.id, \'ShippingEasy\')"><img class="icons" src="/assets/images/deep_import.png"></img></a>' +
                    '</span>' +
                    '<span ng-show="store.store_type==\'Shipstation API 2\'">' +
                      '<a class="btn" ng-hide="import_summary.import_info.status==\'in_progress\'" title="Quick Import" ng-click="issue_import(store.id, 7, \'quick\')"><img class="icons" src="/assets/images/quick_import.png"></img></a>' +
                      '<a class="btn" ng-hide="import_summary.import_info.status==\'in_progress\'" title="Regular Import" ng-click="issue_import(store.id, 7, \'regular\')"><img class="icons" src="/assets/images/reg_import.png"></img></a>' +
                      '<a class="btn ShipstationAPI2" ng-hide="import_summary.import_info.status==\'in_progress\'" title="Deep Import" ng-click="issue_import(store.id, 7, \'deep\')"><img class="icons" src="/assets/images/deep_import.png"></img></a>' +
                    '</span>' +
                    '<a class="btn" ng-show="import_summary.import_info.status==\'in_progress\' && import_summary.import_info.import_summary_type != \'update_locations\'" title="Cancel Import" ng-click="cancel_import(store.id)"><img class="icons" src="/assets/images/cancel_import.png"></img></a>' +
                  '</div>' +
                '</td>' +
              '</tr>' +
            '</table>';
        }
      });

      $scope.issue_import = function (store_id, days, import_type) {
        //console.log(importOrders);
        //alert(store_id + ", "+ days + "," + import_type);
        $('.groove-button.dropdown-toggle.days_select').click();
        $(".place_select").css('display', 'none');
        $scope.import_store_id = null;
        importOrders.issue_import(store_id, days, import_type);
      };

      $scope.cancel_import = function (store_id) {
        //alert("cancel import" + store_id)
        importOrders.cancel_import(store_id);
      };

      $scope.issue_update = function (store_id) {
        stores.shipstation.update_all_locations(store_id);
      };

      $scope.open_popup = function (store_id, span_class) {
        $(".place_select").css('display', 'block');
        if($scope.import_store_id==store_id){
          $(".place_select").css('display', 'none');
          $scope.import_store_id=null;
        } else {
          $scope.import_store_id = store_id;
          $(".place_select").css('display', 'block');
        }
      };

      $scope.show_logout_box = false;
      groovIO.on('ask_logout', function (msg) {
        if (!$scope.show_logout_box) {
          notification.notify(msg.message);
          $scope.show_logout_box = true;
        }
      });

      groovIO.on('hide_logout', function (msg) {
        if ($scope.show_logout_box) {
          notification.notify(msg.message, 1);
          $scope.show_logout_box = false;
        }
      });

      $rootScope.$on("editing-a-var", function (event, data) {
        $scope.currently_editing = (data.ident !== false);
      });

      $scope.log_out = function (who) {
        if (who === 'me') {
          groovIO.log_out({message: ''});
        } else if (who === 'everyone_else') {
          groovIO.emit('logout_everyone_else');
        }
      };
      $scope.stop_editing = function () {
        editable.force_exit();
      };

      $scope.is_active_tab = function (string) {
        var name = $state.current.name;
        if (name.indexOf('.') != -1) {
          name = name.substr(0, name.indexOf('.'))
        }
        return (string == name);
      };
      $scope.notify = function (msg, type) {
        notification.notify(msg, type);
      };
      $scope.import_summary = {};
      var myscope = {};

      $scope.import_all_orders = function () {
        importOrders.do_import($scope);
      };
      $rootScope.focus_search = function (event) {
        var elem;
        if (typeof event != 'undefined') {
          event.preventDefault();
        }
        //if cheatsheet is open, do nothing;
        if ($document.find('.cfp-hotkeys-container').hasClass('in')) {
          return;
        }
        // If in modal
        if ($document.find('body').hasClass('modal-open')) {
          elem = $document.find('.modal-dialog:last .modal-body .search-box');
        } else {
          elem = $document.find('.search-box');
        }
        elem.focus();
        return elem;
      };
      hotkeys.bindTo($scope).add({
        combo: ['return'],
        description: 'Focus search/scan bar (if present)',
        callback: $rootScope.focus_search
      });
      hotkeys.bindTo($scope).add({
        combo: ['mod+shift+e'],
        description: 'Exit Editing mode',
        callback: $scope.stop_editing
      });

      document.onmouseover = function () {
        if (!$scope.mouse_in_page) {
          $scope.$apply(function () {
            $scope.mouse_in_page = true;
          });
        }
      };
      document.onmouseleave = function () {
        if ($scope.mouse_in_page) {
          $scope.$apply(function () {
            $scope.mouse_in_page = false;
          });
        }
      };

      //myscope.get_status();
      $rootScope.$on('$stateChangeStart', function (event, toState, toParams, fromState, fromParams) {
        if ($(".modal").is(':visible') && toState.name != fromState.name) {
          var modal = $modalStack.getTop();
          if (modal && modal.value.backdrop && modal.value.backdrop != 'static' && !$scope.mouse_in_page) {
            event.preventDefault();
            $modalStack.dismiss(modal.key, 'browser-back-button');
          }
        }
      });
      $rootScope.$on('$viewContentLoaded', function () {
        $timeout($rootScope.focus_search);
      });
    }]);
