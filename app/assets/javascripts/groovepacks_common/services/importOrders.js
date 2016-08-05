groovepacks_services.factory("importOrders", ['$http', 'notification', function ($http, notification) {
    return {
      do_import: function () {
        $http.get('/orders/import_all.json', {ignoreLoadingBar: true}).success(function (data) {
          if (data.status) {
            notification.notify(data.success_messages, 1);
          } else {
            notification.notify(data.error_messages);
          }
        }).error(notification.server_error);
      },

      issue_import: function (store_id, no_of_days, import_type) {
        $http.get("/orders/import.json?store_id=" + store_id + "&days="+ no_of_days +"&import_type=" + import_type,
          {ignoreLoadingBar: true}).success(function (data) {
            if (data.status) {
              notification.notify(data.success_messages, 1);
            } else {
              notification.notify(data.error_messages);
            }
          }).error(notification.server_error);
      },

      cancel_import: function (store_id) {
        $http.put('/orders/cancel_import.json',
          {store_id: store_id}).success(function (data) {
            if (data.status) {
              notification.notify(data.success_messages, 1);
            } else {
              notification.notify(data.error_messages);
            }
          }).error(notification.server_error);
      },

      update_popup_display_setting: function(flag) {
        $http.put('/order_import_summary/update_display_setting',
          {flag: flag}).success(function (data) {
            // if (data.status) {
            //   notification.notify(data.success_messages, 1);
            // } else {
            //   notification.notify(data.error_messages);
            // }
          });
      }
      // do_import: function(scope) {

      //     /* Get all the active stores */
      //     $http.get('/stores/getactivestores.json').success(function(data) {
      //         if (data.status)
      //         {
      //             //console.log("data status");
      //             scope.active_stores = [];

      //             for (var i = 0; i < data.stores.length; i++)
      //             {
      //                 var activeStore = new Object();
      //                 activeStore.info = data.stores[i];
      //                 activeStore.message="";
      //                 activeStore.status="in_progress";
      //                 scope.active_stores.push(activeStore);
      //             }
      //             /* for each store send a import request */
      //             for (var i = 0; i < scope.active_stores.length; i++)
      //             {
      //                 //$scope.active_stores[i].status="in_progress";
      //                 //$timeout()
      //                 $http.get('/orders/import_orders/'+scope.active_stores[i].info.id+'.json?activestoreindex='+i).success(
      //                     function(orderdata){

      //                         if (orderdata.status)
      //                         {
      //                             scope.active_stores[orderdata.activestoreindex].status="completed";
      //                             scope.active_stores[orderdata.activestoreindex].message = "Successfully imported "+orderdata.success_imported+
      //                                 " of "+orderdata.total_imported+" orders. "
      //                                 +orderdata.previous_imported+" orders were previously imported";
      //                         }
      //                         else
      //                         {
      //                             scope.active_stores[orderdata.activestoreindex].status="failed";
      //                             for (var j=0; j< orderdata.messages.length; j++) {
      //                                 scope.active_stores[orderdata.activestoreindex].message += orderdata.messages[j];
      //                             }
      //                         }
      //                     }).error(function(data) {
      //                         // console.log(data);
      //                     });
      //             }

      //         }
      //         else
      //         {
      //             // console.log("data status false");
      //             scope.notify("Getting active stores returned error.",0);
      //         }
      //     }).error(function(data) {
      //             scope.notify("Getting active stores failed.",0);
      //         });
      // }
    }
  }]
);
