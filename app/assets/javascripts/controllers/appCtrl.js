groovepacks_controllers.
    controller('appCtrl', [ '$rootScope', '$scope', '$timeout','$modalStack', '$state', '$filter','$document','$window','hotkeys', 'auth','notification','importOrders','groovIO','editable',
    function( $rootScope, $scope, $timeout, $modalStack, $state, $filter, $document, $window, hotkeys, auth,notification,importOrders,groovIO,editable) {

        $scope.$on("user-data-reloaded", function() {
            $scope.current_user = auth;
        });

        groovIO.on('import_status_update',function(message) {

            if (typeof(message) != 'undefined') {
                //console.log("socket",message);
                $scope.import_summary = angular.copy(message);
                $scope.import_groov_popover = {title:'',content:'',data:[]};
                if($scope.import_summary.import_info.status =='completed') {
                    $scope.import_groov_popover.title = 'Last import: '+$filter('date')($scope.import_summary.import_info.updated_at,'EEE MM/dd/yy hh:mm a');
                } else if($scope.import_summary.import_info.status == 'in_progress') {
                    $scope.import_groov_popover.title = 'Import in Progress';
                }  else if($scope.import_summary.import_info.status == 'not_started') {
                    $scope.import_groov_popover.title = 'Import not started '+ $scope.import_summary.import_info.status;
                }
                var logos = {
                    Ebay: {
                          alt:"Ebay",
                          src: "https://s3.amazonaws.com/groovepacker/EBAY-BUTTON.png"
                    },
                    Amazon: {
                            alt:"Amazon",
                            src: "https://s3.amazonaws.com/groovepacker/amazonLogo.jpg"
                    },
                    Magento: {
                        alt:"Magento",
                        src: "https://s3.amazonaws.com/groovepacker/MagentoLogo.jpg"
                    },
                    Shipstation: {
                        alt:"ShipStation",
                        src: "/assets/images/ShipStation_logo.png"
                    },
                    "Shipstation API 2": {
                        alt:"ShipStation",
                        src: "/assets/images/ShipStation_logo.png"
                    },
                    Shipworks: {
                        alt:"ShipWorks",
                        src: "/assets/images/shipworks_logo.png"
                    },
                    CSV: {
                         alt:"CSV",
                        src: "/assets/images/csv_logo.png"
                    }

                };
                for (var i = 0; i < $scope.import_summary.import_items.length; i++) {
                    var import_item = $scope.import_summary.import_items[i];
                    if(import_item && import_item.store_info) {
                        var single_data = {progress:{},progress_product:{},name:''};
                        single_data.logo = logos[import_item.store_info.store_type];
                        single_data.name = import_item.store_info.name;
                        single_data.id = import_item.store_info.id;
                        single_data.progress.type = import_item.import_info.status;
                        single_data.progress.value = 0;
                        single_data.progress.message = '';
                        single_data.progress_product.show = false;
                        single_data.progress_product.value = 0;
                        single_data.progress_product.message = '';
                        single_data.progress_product.type = 'in_progress';


                        if(import_item.import_info.status=='completed') {
                            single_data.progress.value = 100;
                            if(import_item.store_info.store_type == 'Shipworks' ||import_item.store_info.store_type == 'CSV') {
                                single_data.progress.message += 'Last Imported Order #'+import_item.import_info.current_increment_id+' at '+$filter('date')(import_item.import_info.updated_at,'dd MMM hh:mm a');
                            } else if (import_item.import_info.success_imported <= 0) {
                                single_data.progress.message +=' No new orders found.';
                            } else {
                                single_data.progress.message += import_item.import_info.success_imported+' New Orders Imported.';
                            }
                        } else if(import_item.import_info.status=='not_started') {
                            single_data.progress.message += 'Import not started.';
                        } else if(import_item.import_info.status == 'in_progress') {
                            $scope.import_summary.import_info.status = 'in_progress';
                            if(import_item.import_info.to_import > 0) {
                                single_data.progress.value =(((import_item.import_info.success_imported + import_item.import_info.previous_imported)/import_item.import_info.to_import)*100);
                                single_data.progress.message += 'Imported '+(import_item.import_info.success_imported+import_item.import_info.previous_imported)+'/'+import_item.import_info.to_import+' Orders ';
                                if(import_item.import_info.current_increment_id !='') {
                                    single_data.progress.message += 'Current #'+import_item.import_info.current_increment_id+' ';
                                }
                                single_data.progress_product.show = true;
                                if(import_item.import_info.current_order_items > 0 ) {
                                    single_data.progress_product.value = (import_item.import_info.current_order_imported_item/import_item.import_info.current_order_items) *100;
                                    single_data.progress_product.message += 'Imported '+import_item.import_info.current_order_imported_item+'/'+import_item.import_info.current_order_items+' Products';
                                } else {
                                    single_data.progress_product.value = 0;
                                }
                                if(single_data.progress_product.value == 0 ) {
                                    if(import_item.import_info.current_order_items <= 0 ) {
                                        single_data.progress_product.type = 'not_started';
                                        single_data.progress_product.message = 'Import not started';
                                    }
                                } else if(single_data.progress_product.value == 100) {
                                    single_data.progress_product.type = 'completed';
                                }
                            } else {
                                single_data.progress.message += 'Import in progress.';
                            }
                        } else if(import_item.import_info.status=='failed') {
                            single_data.progress.value = 100;
                            if(import_item.import_info.message != '') {
                                single_data.progress.message = import_item.import_info.message;
                            }
                        }
                        $scope.import_groov_popover.data.push(single_data);
                    }
                }
                $scope.import_groov_popover.content =
                '<table style="font-size: 12px;width:100%;">' +
                    '<tr ng-repeat="store in import_groov_popover.data">' +
                        '<td width="60px;" style="white-space: nowrap;">' +
                            '<img ng-src="{{store.logo.src}}" width="60px" alt="{{store.logo.alt}}"/>' +
                        '</td>' +
                        '<td style="white-space: nowrap;">{{store.name}}</td>' +
                        '<td style="width:70%;padding:3px;">' +
                            '<progressbar type="{{store.progress.type}}" value="store.progress.value"> {{store.progress.message}}</progressbar>' +
                            '<progressbar ng-show="store.progress_product.show" type="{{store.progress_product.type}}" value="store.progress_product.value">{{store.progress_product.message}}</progressbar>' +
                        '</td>' +
                        '<td style="text-align:right;width:30%;padding:3px;">' +
                            '<div class="btn-group" ng-hide="import_summary.import_info.status==\'in_progress\'">' + 
                            '<a class="btn" title="Regular Import" ng-click="issue_import(store.id, \'regular\')"><img class="icons" src="/assets/images/reg_import.png"></img></a>' +
                            '<a class="btn" title="Deep Import" ng-click="issue_import(store.id, \'deep\')"><img class="icons" src="/assets/images/deep_import.png"></img></a>' + 
                            '<a class="btn" title="Cancel Import" ng-click="cancel_import(store.id)"><img class="icons" src="/assets/images/cancel_import.png"></img></a>' + 
                            '</div>'
                        '</td>'+
                    '</tr>' +
                '</table>';

            }
        });
        
        $scope.issue_import = function(store_id, import_type) {
            //console.log(importOrders);
            importOrders.issue_import(store_id, import_type)
        }

        $scope.cancel_import = function(store_id) {
            //alert("cancel import" + store_id)
        }

        $scope.show_logout_box = false;
        groovIO.on('ask_logout',function(msg) {
            if(! $scope.show_logout_box) {
                notification.notify(msg.message);
                $scope.show_logout_box = true;
            }
        });

        groovIO.on('hide_logout',function(msg) {
            if($scope.show_logout_box) {
                notification.notify(msg.message, 1);
                $scope.show_logout_box = false;
            }
        });

        $rootScope.$on("editing-a-var",function(event,data) {
            $scope.currently_editing = (data.ident !== false);
        });

        $scope.log_out = function(who) {
            if(who === 'me') {
                groovIO.log_out({message:''});
            } else if (who === 'everyone_else') {
                groovIO.emit('logout_everyone_else');
            }
        };
        $scope.stop_editing = function() {
            editable.force_exit();
        };

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
        hotkeys.bindTo($scope).add({
           combo: ['mod+shift+e'],
           description:'Exit Editing mode',
           callback:$scope.stop_editing
        });

        document.onmouseover = function() {
            if(!$scope.mouse_in_page) {
                $scope.$apply(function() {
                    $scope.mouse_in_page = true;
                });
            }
        };
        document.onmouseleave = function() {
            if($scope.mouse_in_page) {
                $scope.$apply(function () {
                    $scope.mouse_in_page = false;
                });
            }
        };

        //myscope.get_status();
        $rootScope.$on('$stateChangeStart',function(event,toState,toParams,fromState,fromParams) {
            if($(".modal").is(':visible') && toState.name !=fromState.name) {
                var modal = $modalStack.getTop();
                if (modal && modal.value.backdrop && modal.value.backdrop != 'static' && !$scope.mouse_in_page) {
                    event.preventDefault();
                    $modalStack.dismiss(modal.key, 'browser-back-button');
                }
            }
        });
        $rootScope.$on('$viewContentLoaded',function() {
            $timeout($rootScope.focus_search);
        });
}]);
