groovepacks_controllers.
  controller('appCtrl', ['$http', '$rootScope', '$scope', '$timeout', '$modalStack', '$state', '$filter', '$document', '$window', 'hotkeys', 'auth', 'notification', 'importOrders', 'groovIO', 'editable', 'stores',
    function ($http, $rootScope, $scope, $timeout, $modalStack, $state, $filter, $document, $window, hotkeys, auth, notification, importOrders, groovIO, editable, stores) {
      $scope.import_store_id = null;
      $scope.bc_deep_import_days = 1;
      $scope.se_deep_import_days = 1;
      $scope.ss_deep_import_days = 1;
      $scope.tp_deep_import_days = 1;
      $scope.add_popup_summary_on_load = true;
      $scope.$on("user-data-reloaded", function () {
        $scope.current_user = auth;
      });

      groovIO.on('import_status_update', function (message) {

        if (typeof(message) !== 'undefined') {
          //console.log("socket",message);
          $scope.import_summary = angular.copy(message);
          $scope.import_groov_popover = {title: '', content: '', data: []};
          var get_import_type = function () {
            if ($scope.import_summary.import_info.import_summary_type === 'update_locations') {
              return ("Update");
            } else {
              return ("Import");
            }
          };

          var get_import_type_past = function () {
            if ($scope.import_summary.import_info.import_summary_type === 'update_locations') {
              return ("Updated");
            } else {
              return ("Imported");
            }
          };
          
          if ($scope.import_summary.import_info.status === 'completed') {
            $scope.import_groov_popover.title = 'Last ' + get_import_type() + ': ' +
              $filter('date')($scope.import_summary.import_info.updated_at,
                'EEE MM/dd/yy hh:mm a');
          } else if ($scope.import_summary.import_info.status === 'in_progress') {
            $scope.import_groov_popover.title = get_import_type() + ' in Progress';
          } else if ($scope.import_summary.import_info.status === 'not_started') {
            $scope.import_groov_popover.title = get_import_type() + ' not started';
          } else if ($scope.import_summary.import_info.status === 'cancelled') {
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
            "Magento API 2": {
              alt: "Magento API 2",
              src: "/assets/images/MagentoLogo.jpg"
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
            },
            "Teapplix": {
              alt: "Teapplix",
              src: "/assets/images/teapplix-logo.png"
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

              if (import_item.import_info.status === 'completed' || import_item.import_info.status === 'cancelled') {
                single_data.progress.value = 100;
                if (import_item.store_info.store_type === 'Shipworks' || import_item.store_info.store_type === 'CSV') {
                  single_data.progress.message += 'Last ' + get_import_type_past() + ' Order #' + import_item.import_info.current_increment_id + ' at ' + $filter('date')(import_item.import_info.updated_at, 'dd MMM hh:mm a');
                } else if (import_item.import_info.success_imported <= 0) {
                  if ($scope.import_summary.import_info.import_summary_type === 'update_locations') {
                    single_data.progress.message += ' No updates made. Locations are upto date.';
                  } else if(import_item.import_info.updated_orders_import > 0){
                    single_data.progress.message += import_item.import_info.updated_orders_import + ' Orders were updated.';
                  } else {
                    single_data.progress.message += ' No new orders found.';
                  }
                } else {
                  if ($scope.import_summary.import_info.import_summary_type === 'update_locations') {
                    single_data.progress.message += import_item.import_info.success_imported + ' Orders were updated.';
                  } else if(import_item.import_info.updated_orders_import > 0){
                    single_data.progress.message += import_item.import_info.success_imported + ' New Orders Imported and ';
                    single_data.progress.message += import_item.import_info.updated_orders_import + ' Orders were updated.';
                  } else {
                    single_data.progress.message += import_item.import_info.success_imported + ' New Orders Imported.';
                  }
                }
                if (import_item.import_info.status === 'cancelled') {
                  single_data.progress.message += ' The import was cancelled.';
                }
              } else if (import_item.import_info.status === 'not_started') {
                single_data.progress.message += get_import_type() + ' not started.';
              } else if (import_item.import_info.status === 'in_progress') {
                $scope.import_summary.import_info.status = 'in_progress';
                if (import_item.import_info.to_import > 0) {
                  single_data.progress.value = (((import_item.import_info.success_imported + import_item.import_info.previous_imported) / import_item.import_info.to_import) * 100);
                  single_data.progress.message += get_import_type_past() + ' ' +
                    (import_item.import_info.success_imported + import_item.import_info.previous_imported) + '/' + import_item.import_info.to_import + ' Orders ';
                  if (import_item.import_info.current_increment_id !== '') {
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
                  if (single_data.progress_product.value === 0) {
                    if (import_item.import_info.current_order_items <= 0) {
                      single_data.progress_product.type = 'not_started';
                      single_data.progress_product.message = 'waiting on source...';
                    }
                  } else if (single_data.progress_product.value === 100) {
                    single_data.progress_product.type = 'completed';
                  }
                } else {
                  single_data.progress.message += get_import_type() + ' in progress.';
                }
              } else if (import_item.import_info.status === 'failed') {
                single_data.progress.value = 100;
                if (import_item.import_info.message !== '') {
                  single_data.progress.message = import_item.import_info.message;
                }
              } else if (import_item.import_info.status === 'cancelled') {
                single_data.progress.value = 100;
              } else {
                single_data.progress.value = 100;
                single_data.progress.type = 'completed';
                if (import_item.import_info.message !== '') {
                  single_data.progress.message = import_item.import_info.message;
                }
              }
              $scope.import_groov_popover.data.push(single_data);
            }
          }
          $scope.import_groov_popover.content = 
            '<table style="font-size: 12px;width:100%;">' +
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
                    '<div ng-show="store.store_type==\'BigCommerce\'" style="display: flex;">' +
                      '<a class="btn" ng-hide="import_summary.import_info.status==\'in_progress\'" title="Regular Import" ng-click="issue_import(store.id, 4, \'regular\')"><img class="icons" src="/assets/images/reg_import.png"></img></a>' +
                      '<div ng-hide="import_summary.import_info.status==\'in_progress\'" ng-mouseover="show_days_select(store, true)" ng-mouseleave="show_days_select(store, false)" style="width: 120px;">' +
                        '<a class="btn" title="Deep Import" ng-click="issue_import(store.id, store.days, \'deep\')" style="float: left;"><img class="icons" src="/assets/images/deep_import.png"></img></a>' +
                        '<input type="number" ng-model="store.days" ng-value="{{bc_deep_import_days}}" data-import="{{store.id}}" ng-mouseleave="check_days_value(store)" max="30" style="display: none;font-size: 15px;height: 30px;width: 50px;"/>' +
                      '</div>' +
                    '</div>' +
                    '<div ng-show="store.store_type==\'ShippingEasy\'" style="display: flex;">' +
                      '<a class="btn" ng-hide="import_summary.import_info.status==\'in_progress\'" title="Regular Import" ng-click="issue_import(store.id, 4, \'regular\')"><img class="icons" src="/assets/images/reg_import.png"></img></a>' +
                      '<div  ng-hide="import_summary.import_info.status==\'in_progress\'" ng-mouseover="show_days_select(store, true)" ng-mouseleave="show_days_select(store, false)" style="width: 120px;">' +
                        '<a class="btn" title="Deep Import" ng-click="issue_import(store.id, store.days, \'deep\')" style="float: left;"><img class="icons" src="/assets/images/deep_import.png"></img></a>' +
                        '<input type="number" ng-model="store.days" ng-value="{{se_deep_import_days}}" data-import="{{store.id}}" ng-mouseleave="check_days_value(store)" max="30" style="display: none;font-size: 15px;height: 30px;width: 50px;"/>' +
                      '</div>' +
                    '</div>' +
                    '<div ng-show="store.store_type==\'Shipstation API 2\'" style="display: flex;">' +
                      '<a class="btn" ng-hide="import_summary.import_info.status==\'in_progress\'" title="Tagged Import" ng-click="issue_import(store.id, 7, \'tagged\')"><img class="icons" src="/assets/images/tagged_import.png"></img></a>' +
                      '<a class="btn" ng-hide="import_summary.import_info.status==\'in_progress\'" title="Quick Import" ng-click="issue_import(store.id, 7, \'quick\')"><img class="icons" src="/assets/images/quick_import.png"></img></a>' +
                      '<a class="btn" ng-hide="import_summary.import_info.status==\'in_progress\'" title="Regular Import" ng-click="issue_import(store.id, 7, \'regular\')"><img class="icons" src="/assets/images/reg_import.png"></img></a>' +
                      '<div ng-hide="import_summary.import_info.status==\'in_progress\'" ng-mouseover="show_days_select(store, true)" ng-mouseleave="show_days_select(store, false)" style="width: 120px;">' +
                        '<a class="btn" title="Deep Import" ng-click="issue_import(store.id, store.days, \'deep\')" style="float: left;"><img class="icons" src="/assets/images/deep_import.png"></img></a>' +
                        '<input type="number" ng-model="store.days" ng-value="{{ss_deep_import_days}}" data-import="{{store.id}}" ng-mouseleave="check_days_value(store)" max="30" style="display: none;font-size: 15px;height: 30px;width: 50px;"/>' +
                      '</div>' +
                    '</div>' +
                    '<div ng-show="store.store_type==\'Teapplix\'" style="display: flex;">' +
                      '<div  ng-hide="import_summary.import_info.status==\'in_progress\'" ng-mouseover="show_days_select(store, true)" ng-mouseleave="show_days_select(store, false)" style="width: 120px;">' +
                        '<a class="btn" title="Deep Import" ng-click="issue_import(store.id, store.days, \'regular\')" style="float: left;"><img class="icons" src="/assets/images/reg_import.png"></img></a>' +
                        '<input type="number" ng-model="store.days" ng-value="{{tp_deep_import_days}}" data-import="{{store.id}}" ng-mouseleave="check_days_value(store)" max="30" style="display: none;font-size: 15px;height: 30px;width: 50px;"/>' +
                      '</div>' +
                    '</div>' +
                    '<a class="btn" ng-show="import_summary.import_info.status==\'in_progress\' && import_summary.import_info.import_summary_type != \'update_locations\'" title="Cancel Import" ng-click="cancel_import(store.id)"><img class="icons" src="/assets/images/cancel_import.png"></img></a>' +
                  '</div>' +
                '</td>' +
              '</tr>' +
            '</table>';
        }
      });

      $scope.issue_import = function (store_id, days, import_type) {
        //console.log(importOrders);
        importOrders.issue_import(store_id, days, import_type);
      };

      $scope.update_popup_display_setting = function (flag) {
        importOrders.update_popup_display_setting(flag);
      };

      $scope.cancel_import = function (store_id) {
        //alert("cancel import" + store_id)
        importOrders.cancel_import(store_id);
      };

      $scope.sign_out = function () {
        console.log('sign_out');
        localStorage.removeItem('access_token');
        localStorage.removeItem('refresh_token');
        localStorage.removeItem('created_at');
        $http.delete('/users/sign_out.json').then(function (data) {
          $window.location.href = '/users/sign_in';
        });
      };

      $scope.issue_update = function (store_id) {
        stores.shipstation.update_all_locations(store_id);
      };

      $scope.show_days_select = function (store, show) {
        store.days = $scope.get_deep_import_days_for_store(store);
        
        // if(store.days ==undefined) {
        //   store.days=1;
        // }
        if(show===true) {
          $('[data-import='+store.id+']').css('display', 'block');
        } else {
          $('[data-import='+store.id+']').css('display', 'none');
        }
      };

      $scope.check_days_value = function (store) {
        var element_val = parseInt(store.days);
        if(element_val>30) {
          store.days=30;
        }
        $scope.set_deep_import_days_for_store(store);
      };

      $scope.get_deep_import_days_for_store = function(store){
        var days = 1;
        if(store.store_type==="BigCommerce"){
          days = $scope.bc_deep_import_days;
        }
        if(store.store_type==="ShippingEasy"){
          days = $scope.se_deep_import_days;
        }
        if(store.store_type==="Shipstation API 2"){
          days = $scope.ss_deep_import_days;
        }
        if(store.store_type==="Teapplix"){
          days = $scope.tp_deep_import_days;
        }
        return days;
      };

      $scope.set_deep_import_days_for_store = function(store){
        if(store.store_type==="BigCommerce"){
          $scope.bc_deep_import_days = store.days;
        }
        if(store.store_type==="ShippingEasy"){
          $scope.se_deep_import_days = store.days;
        }
        if(store.store_type==="Shipstation API 2"){
          $scope.ss_deep_import_days = store.days;
        }
        if(store.store_type==="Teapplix"){
          $scope.tp_deep_import_days = store.days;
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
        if (name.indexOf('.') !== -1) {
          name = name.substr(0, name.indexOf('.'));
        }
        return (string === name);
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
        if (typeof event !== 'undefined') {
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
        if ($(".modal").is(':visible') && toState.name !== fromState.name) {
          var modal = $modalStack.getTop();
          if (modal && modal.value.backdrop && modal.value.backdrop !== 'static' && !$scope.mouse_in_page) {
            event.preventDefault();
            $modalStack.dismiss(modal.key, 'browser-back-button');
          }
        }
      });
      $rootScope.$on('$viewContentLoaded', function () {
        $timeout($rootScope.focus_search);
      });
    }]);
