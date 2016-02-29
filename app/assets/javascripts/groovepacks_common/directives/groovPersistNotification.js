groovepacks_directives.directive('groovPersistNotification', ['$window', '$document', '$sce', '$timeout', '$interval', 'groovIO', 'orders', 'stores', 'notification', '$rootScope', 'settings', function ($window, $document, $sce, $timeout, $interval, groovIO, orders, stores, notification, $rootScope, settings) {
  return {
    restrict: "A",
    templateUrl: "/assets/views/directives/persistnotification.html",
    scope: {},
    link: function (scope, el, attrs) {
      var myscope = {};
      myscope.timers = {};
      myscope.default = function () {
        return {
          glow: false,
          percent: 0,
          ticker: null,
          type: 'success',
          details: '',
          message: ''
        };
      };

      /* For dev lazy logging
       myscope.timer = function(hash,action) {
       if(typeof myscope.timers[hash] == "undefined") {
       myscope.timers[hash] = {
       start_time: null
       };
       }
       if (typeof action == "undefined" || action == "start") {
       if (myscope.timers[hash].start_time === null) {
       myscope.timers[hash].start_time = (new Date()).getTime();
       console.log('started');
       }
       } else if (action == "stop") {
       console.log((new Date()).getTime() - myscope.timers[hash].start_time, " Milliseconds. Stopped.");
       delete myscope.timers[hash];
       } else if(action == "tick") {
       console.log((new Date()).getTime() - myscope.timers[hash].start_time, "Milliseconds. Tick.");
       myscope.timers[hash].start_time = (new Date()).getTime();
       }


       };
       */

      myscope.repurpose_selected = function () {
        if (typeof scope.notifications[scope.selected] == "undefined") {
          scope.selected = '';
        }

        for (var i in scope.notifications) {
          if (scope.notifications.hasOwnProperty(i)) {
            if (scope.selected != '' && scope.notifications[scope.selected].type == 'in_progress') return;
            if (scope.notifications[i].type == 'in_progress') {
              scope.selected = i;
            } else if (scope.notifications[i].percent < 100) {
              if (scope.selected == '') {
                scope.selected = i;
              }
              if (scope.notifications[i].type == 'paused') {
                scope.selected = i;
              }
              if (scope.notifications[scope.selected].type == 'paused') continue;
              if (scope.notifications[i].type == 'scheduled') {
                scope.selected = i;
              }
              if (scope.notifications[scope.selected].type == 'scheduled') continue;
              if (scope.notifications[i].type == 'cancelled') {
                scope.selected = i;
              }


            }
          }
        }
      };

      scope.notifications = {};
      scope.selected = '';
      scope.detail_open = false;
      groovIO.forward(['pnotif'], scope);
      /*
       var test = $interval(function() {
       scope.notifications['default_state'].show = true;
       scope.notifications['default_state'].percent += 10;
       scope.notifications['default_state'].type = 'warning';
       scope.notifications['default_state'].message = $sce.trustAsHtml('<b>Test:</b> '+scope.notifications['default_state'].percent+'/ 100');

       if(scope.notifications['default_state'].percent == 100) {
       scope.notifications['default_state'].type = 'success';
       scope.notifications['default_state'].message = $sce.trustAsHtml('<b>Test: Complete!</b>');
       $interval.cancel(test);
       }
       },2000);
       */
      myscope.generate_barcode_status = function (message, hash) {
        scope.notifications[hash].percent = (message['current_order_position'] / message['total_orders']) * 100;
        var notif_message = '<b>Generating&nbsp;Packing&nbsp;Slips:</b>&nbsp;';
        var notif_details = '';
        notif_details += ' <b>Next Order&nbsp;#' + message['next_order_increment_id'] + '</b>';
        scope.notifications[hash].type = message['status'];
        myscope.repurpose_selected();
        if (message['status'] == "scheduled") {
          notif_message += 'Queued&nbsp;' + message['total_orders'] + '&nbsp;Orders';
        } else if (message['status'] == "in_progress") {
          notif_message += message['current_order_position'] + '/' + message['total_orders'] + '&nbsp;';
          notif_details = '<b>Current Order&nbsp;#' + message['current_increment_id'] + '</b> <br/>' + notif_details;
        } else if (message['status'] == "completed" || message['status'] == "cancelled") {
          notif_details = '';
          $timeout(function () {
            delete scope.notifications[hash];
            myscope.repurpose_selected();
          }, 5000);
          groovIO.emit('delete_pnotif', hash);
          if (message['status'] == "completed") {
            notif_message += "Complete!";
            $window.message = message;
            if(
                typeof $window.order_modified != 'undefined' &&
                $window.order_modified.indexOf(message['id']) > -1
              ){
              $window.open(message.url);
            }
          } else if (message['status'] == "cancelled") {
            notif_message += "Cancelled";
          }
        }

        scope.notifications[hash].message = $sce.trustAsHtml(notif_message);
        scope.notifications[hash].details = $sce.trustAsHtml(notif_details);
        scope.notifications[hash].cancel = function ($event) {
          $event.preventDefault();
          $event.stopPropagation();
          orders.list.cancel_pdf_gen(message.id).then(function () {
            myscope.repurpose_selected();
          });
        };
      };

      // method to cancel all the bulk actions
      scope.bulkCancelAction = function(){
        settings.cancel_bulk_actions(scope.bulk_action_ids).then(function(response){
          myscope.repurpose_selected();
        });
      }

      myscope.groove_bulk_actions = function (message, hash) {
        scope.notifications[hash].percent = (message['completed'] / message['total']) * 100;
        var notif_message = '';
        var notif_details = '';
        if (message['identifier'] == 'product') {
          if (message['activity'] == 'status_update') {
            notif_message = '<b>Product Status Update:</b> ';
          } else if (message['activity'] == 'delete') {
            notif_message = '<b>Product Delete:</b> ';
          } else if (message['activity'] == 'duplicate') {
            notif_message = '<b>Product Duplicate:</b> ';
          } else if (message['activity'] == 'export') {
            notif_message = '<b>Taking Backup: ' + message['current'] + '</b> ';
          }

        } else if (message['identifier'] == 'inventory') {
          if (message['activity'] == 'enable') {
            notif_message = '<b>Enabling Inventory Tracking:</b> ';
          } else if (message['activity'] == 'disable') {
            notif_message = '<b>Disabling Inventory Tracking:</b> ';
          }
        } else if (message['identifier'] == 'csv_import') {
          if (message['activity'] == 'kit') {
            notif_message = '<b>Importing Kits:</b> ';
          }
        }
        myscope.repurpose_selected();
        scope.notifications[hash].type = message['status'];
        if (message['status'] == "scheduled") {
          notif_message += 'Queued';
        } else if (message['status'] == "in_progress") {
          notif_message += message['completed'] + '/' + message['total'] + '&nbsp;';
          notif_details = '<b>Currently processing:<b> ' + message['current'] + notif_details;
        } else if (message['status'] == "completed" || message['status'] == "cancelled" || message['status'] == 'failed') {
          $rootScope.$emit('bulk_action_finished', message);
          notif_details = '';
          $timeout(function () {
            delete scope.notifications[hash];
            myscope.repurpose_selected();
          }, 5000);
          groovIO.emit('delete_tenant_pnotif', hash);
          if (message['status'] == "completed") {
            notif_message += "Complete!";
          } else if (message['status'] == "cancelled") {
            notif_message += "Cancelled";
          } else if (message['status'] == 'failed') {
            notif_message += 'Failed';
            notification.notify(message['messages']);
          }
        }
        scope.notifications[hash].message = $sce.trustAsHtml(notif_message);
        scope.notifications[hash].details = $sce.trustAsHtml(notif_details);
        scope.notifications[hash].cancel = function ($event) {
          $event.preventDefault();
          $event.stopPropagation();
          // Using the same api for cancel of single bulk action
          // object as well as bulk cancel action, so converting the
          // message id into an array
          var messageId = [message.id];
          settings.cancel_bulk_action(messageId).then(function () {
            myscope.repurpose_selected();
          });
        };
      };

      myscope.csv_product_import = function (message, hash) {
        var import_stock_messages = {
          importing_products: 'Product Import in progress',
          importing_skus: 'SKU Import in progress',
          importing_barcodes: 'Barcode Import in Progress',
          importing_cats: 'Categories Import in Progress',
          importing_images: 'Images import in Progress',
          importing_inventory: 'Inventory Data import in Progress',
          processing_status: 'Updating Product Status'
        };
        scope.notifications[hash].percent = (message['success'] / message['total']) * 100;
        myscope.repurpose_selected();
        var notif_message = '<b>Product CSV import:</b> ';
        var notif_details = '';
        if (message['status'] == 'scheduled') {
          scope.notifications[hash].type = 'scheduled';
          notif_message += 'Queued';
        } else if (['processing_csv', 'processing_products', 'importing_products', 'processing_rest', 'importing_skus', 'importing_barcodes', 'importing_cats', 'importing_images', 'importing_inventory', 'processing_status'].indexOf(message['status']) >= 0) {
          scope.notifications[hash].type = message.status.split('_').shift();
          if (message['status'] == 'processing_csv') {
            notif_message += 'Processing CSV file ';
          } else if (message['status'] == 'processing_products') {
            notif_message += 'Preparing to import products';
          } else if (message['status'] == 'processing_rest') {
            if (scope.notifications[hash].ticker !== null) {
              $interval.cancel(scope.notifications[hash].ticker);
              scope.notifications[hash].ticker = null;
            }
            notif_message += 'Preparing to import Skus, Barcodes, Categories, Images and Inventory Data.';
          }

          if (['importing_products', 'importing_skus', 'importing_barcodes', 'importing_cats', 'importing_images', 'importing_inventory', 'processing_status'].indexOf(message['status']) >= 0) {
            notif_message += import_stock_messages[message['status']];
            if (notif_message == '') {
              notif_message += 'Import in Progress.';
            }
            if (scope.notifications[hash].ticker !== null) {
              $interval.cancel(scope.notifications[hash].ticker);
              scope.notifications[hash].ticker = null;
            }
            scope.notifications[hash].percent = 5;
            scope.notifications[hash].ticker = $interval(function () {
              var percent = scope.notifications[hash].percent;
              if (percent <= 25) {
                percent += 0.5;
              }
              if (percent <= 50) {
                percent += 0.5;
              }
              if (percent <= 75) {
                percent += 0.5;
              }
              if (percent <= 90) {
                percent += 0.5;
              }
              if (percent <= 95 && percent > 90) {
                percent += 0.2;
              }
              if (percent < 99.5 && percent > 95) {
                percent += 0.1;
              }
              scope.notifications[hash].percent = percent;
            }, 1000);
            notif_details = '<b>Cancel will not work now.</b>';
          } else {
            notif_details = '<b>Processed: ' + message['success'] + '/' + message['total'] + '</b> <br/>';
            notif_details += '<b>Current Product SKU: ' + message['current_sku'] + '</b> <br/>';
          }
        } else if (message['status'] == 'completed' || message['status'] == 'cancelled') {
          scope.notifications[hash].type = message['status'];
          notif_details = '';
          if (scope.notifications[hash].ticker !== null) {
            $interval.cancel(scope.notifications[hash].ticker);
          }
          $timeout(function () {
            delete scope.notifications[hash];
            myscope.repurpose_selected();
          }, 5000);
          groovIO.emit('delete_tenant_pnotif', hash);
          if (message['status'] == "completed") {
            notif_message += "Complete! Imported " + message["success_imported"] + " New Products. Updated " + message["success_updated"] + " Products.";
            if (message["duplicate_file"] > 0) {
              notification.notify(message["duplicate_file"] + ' items appeared in the import file more than once and were skipped.', 2);
            }
            if (message["duplicate_db"] > 0) {
              notification.notify(message["duplicate_db"] + ' items existed in the database and were skipped.', 2);
            }
            scope.notifications[hash].percent = 100;
          } else if (message['status'] == "cancelled") {
            notif_message += "Cancelled";
          }
        }
        scope.notifications[hash].message = $sce.trustAsHtml(notif_message);
        scope.notifications[hash].details = $sce.trustAsHtml(notif_details);
        scope.notifications[hash].cancel = function ($event) {
          $event.preventDefault();
          $event.stopPropagation();
          stores.csv.cancel_product_import(message.id).then(myscope.repurpose_selected);
        };
      };

      scope.toggle_detail = function () {
        $('#notification').toggleClass('pnotif-open');
        scope.detail_open = !scope.detail_open;
        if (scope.detail_open) {
          if (scope.selected == '') {
            myscope.repurpose_selected();
          }
          scope.bar_glow = false;
          for (var i in scope.notifications) {
            if (scope.notifications.hasOwnProperty(i)) {
              scope.notifications[i].glow = false;
            }
          }
        }
      };

      scope.$on('groove_socket:pnotif', function (event, messages) {
        // Saving original bulk action ids for later use.
        if(messages[0] && messages[0].type === 'groove_bulk_actions') {
          scope.bulk_action_ids = [];
          angular.forEach(messages, function(item){
            scope.bulk_action_ids.push(item.data.id);
          });
        }
        if (messages instanceof Array === false) {
          messages = [messages];
        }
        angular.forEach(messages, function (message) {
          if (typeof myscope[message['type']] == "function") {
            if (typeof message['data'] == "undefined") return;
            if (typeof scope.notifications[message['hash']] == 'undefined') {
              scope.notifications[message['hash']] = myscope.default();
            }
            if (scope.selected === '') {
              scope.selected = message['hash'];
            } else if (scope.selected !== message['hash']) {
              scope.notifications[message['hash']].glow = true;
              if (!scope.detail_open) {
                scope.bar_glow = true;
              }
            }
            myscope[message['type']](message['data'], message['hash']);
          }
        });
      });
    }
  };
}]);
