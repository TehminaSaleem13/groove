groovepacks_services.factory("importOrders", ['$http',function($http) {
        return {
            do_import: function(scope) {
               $http.get('/orders/import_all.json',{ignoreLoadingBar: true}).success(function(data) {
                 scope.notify("Scouring the interwebs for new orders...",1);}).error(function(data) {
                        scope.notify("Getting import orders failed.",0);
                    });
            }
            // do_import: function(scope) {

            //     /* Get all the active stores */
            //     $http.get('/store_settings/getactivestores.json').success(function(data) {
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
            //                 $http.get('/orders/importorders/'+scope.active_stores[i].info.id+'.json?activestoreindex='+i).success(
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
