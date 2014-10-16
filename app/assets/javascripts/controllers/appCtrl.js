groovepacks_controllers.
    controller('appCtrl', [ '$rootScope', '$scope', '$http', '$timeout', '$interval', '$stateParams','$modalStack', '$location', '$state', '$cookies', '$filter','$document','hotkeys', 'auth','notification','importOrders','$interpolate','groovIO',
    function( $rootScope, $scope, $http, $timeout, $interval, $stateParams, $modalStack, $location, $state, $cookies, $filter, $document, hotkeys, auth,notification,importOrders,$interpolate,groovIO) {

        $scope.$on("user-data-reloaded", function() {
            $scope.current_user = auth;
        });

        groovIO.on('import_status_update',function(message) {
            console.log("socket",message);
            myscope.get_status();
        });

        $scope.$on("editing-a-var",function(event,data) {
            $scope.current_editing = data.ident;
        });

        $scope.is_active_tab = function(string) {
                var name = $state.current.name;
                if(name.indexOf('.') != -1) {
                    name = name.substr(0, name.indexOf('.'))
                }
            return (string == name);
        };
        $scope.notify = function(msg,type) {
            notification.notify(msg,type);
        };
        $scope.import_summary = {};
        var myscope = {};

        $scope.import_all_orders = function () {
            importOrders.do_import($scope);
        };
        //call a method at timeout of say 60 seconds.
        myscope.get_status = function() {
            $http.get('/orders/import_status.json',{ignoreLoadingBar: true}).success(function(response) {

                if (response.status && typeof(response.data.import_summary) != 'undefined') {
                    console.log("http",response.data.import_summary);
                    $scope.import_summary = response.data.import_summary;
                    $scope.import_groov_popover = {title:'',content:''};

                    if($scope.import_summary.import_info.status =='completed') {
                        $scope.import_groov_popover.title = $interpolate('Last import: ' +
                            '{{import_summary.import_info.updated_at | date:\'EEE MM/dd/yy hh:mm a\'}}')($scope);
                    } else if($scope.import_summary.import_info.status == 'in_progress') {
                        $scope.import_groov_popover.title = 'Import in Progress';
                    }  else if($scope.import_summary.import_info.status == 'not_started') {
                        $scope.import_groov_popover.title = 'Click to Start Import';
                    }

                    var content = '<table style="font-size: 12px;">';
                    for(var i=0; i<$scope.import_summary.import_items.length; i++) {
                        var cur_item = $scope.import_summary.import_items[i];
                        if(cur_item && cur_item.store_info) {
                            content+='<tr><td>';
                            if(cur_item.store_info.store_type=='Ebay') {
                                content += '<img src="https://s3.amazonaws.com/groovepacker/EBAY-BUTTON.png" width="60px" ' +
                                           'height="50px" alt="EBay"/>'
                            } else if(cur_item.store_info.store_type=='Amazon') {
                                content += '<img src="https://s3.amazonaws.com/groovepacker/amazonLogo.jpg" width="60px" ' +
                                           'height="50px" alt="Amazon"/>'
                            } else if(cur_item.store_info.store_type=='Magento') {
                                content += '<img src="https://s3.amazonaws.com/groovepacker/MagentoLogo.jpg" width="60px" ' +
                                           'height="50px" alt="Magento"/>'
                            } else if(cur_item.store_info.store_type=='Shipstation') {
                                content += '<img src="/assets/images/ShipStation_logo.png" width="60px" ' +
                                           'height="50px" alt="Shipstation"/>'
                            }
                            content+='</td>';
                            content+=$interpolate('<td>{{store_info.name}}</td>')(cur_item);
                            content+='<td style="text-align:right;">&nbsp;';
                            if(cur_item.import_info.status=='completed') {
                                if (cur_item.import_info.success_imported == 0) {
                                    content+=' No new orders found.';
                                } else {
                                    content+=$interpolate(' {{import_info.success_imported}} New Orders Imported.')(cur_item);
                                }
                            } else if(cur_item.import_info.status=='not_started') {
                                content+='Import not started.';
                            } else if(cur_item.import_info.status=='in_progress') {
                                content+='Import in progress.';
                            } else if(cur_item.import_info.status=='failed') {
                                content+='Import failed.';
                            }
                            content+='</td></tr>';
                        }

                    }
                    content+='</table>';


                    $scope.import_groov_popover.content =  content;

                }
            }).error(function(data) {});
        };
        //$interval(myscope.get_status, 2000);
        $rootScope.focus_search = function(event) {
            if (typeof event != 'undefined') {
                event.preventDefault();
            }
            //if cheatsheet is open, do nothing;
            if($document.find('.cfp-hotkeys-container').hasClass('in')){
                return;
            }
            // If in modal
            if($document.find('body').hasClass('modal-open')) {
                $document.find('.modal-dialog:last .modal-body .search-box').focus();
            } else {
                $document.find('.search-box').focus();
            }
        };
        hotkeys.bindTo($scope).add({
            combo: ['return'],
            description:'Focus search/scan bar (if present)',
            callback:$rootScope.focus_search
        });

        myscope.get_status();
        $rootScope.$on('$stateChangeStart',function(event,toState,toParams,fromState,fromParams) {
            if($(".modal").is(':visible') && toState.name !=fromState.name) {
                var modal = $modalStack.getTop();
                if (modal && modal.value.backdrop && modal.value.backdrop != 'static' ) {
                    event.preventDefault();
                    $modalStack.dismiss(modal.key, 'browser-back-button');
                }
            }
        });
        $rootScope.$on('$viewContentLoaded',function() {
            $timeout($rootScope.focus_search);
        });
}]);
