groovepacks_admin_controllers.
controller('scanPackSettingsCtrl', [ '$scope', '$http', '$timeout', '$location', '$state', '$cookies', 'scanPack', 'groov_translator','$modal',
function( $scope, $http, $timeout, $location, $state, $cookies, scanPack,groov_translator,$modal) {

    var myscope = {};


    myscope.init = function() {
        $scope.setup_page('system','scan_pack');
        $scope.translations = {
            "headings":{
                "options": "",
                "feedback": "",
                "scan_actions": "",
                "scan_actions_sub_head": ""
            },
            "labels":{
                "enable_click_sku":"",
                "ask_tracking_number":"",
                "show_success_image":"",
                "show_order_complete_image":"",
                "show_fail_image":"",
                "for":"",
                "seconds":"",
                "play_success_sound":"",
                "play_fail_sound":"",
                "play_order_complete_sound":"",
                "scan":"",
                "skip_code":"",
                "note_from_packer_code":"",
                "service_issue_code":"",
                "restart_code":"",
                "type_scan_code":"",
                "escape_string":"",
                "lot_number":"",
                "show_customer_notes":"",
                "show_internal_notes":""
            },
            "tooltips" :{
                "enable_click_sku":"",
                "ask_tracking_number":"",
                "feedback":"",
                "skip_code":"",
                "note_from_packer_code":"",
                "service_issue_code":"",
                "restart_code":"",
                "type_scan_code":"",
                "type_in_counts":"",
                "escape_string":"",
                "ask_post_scanning_functions":"",
                "show_internal_notes":"",
                "show_customer_notes":""
            }
        };
        groov_translator.translate('settings.system.scan_pack',$scope.translations);
        $scope.scan_pack = scanPack.settings.model();
        scanPack.settings.get($scope.scan_pack);
    };


    $scope.per_product_setting = function(key) {
        $modal.open({
            templateUrl: '/assets/views/modals/settings/system/product_list.html',
            controller: 'productListModal',
            size: 'lg',
            resolve: {
                context_data: function () {
                    var enabled = false;
                    var type = '';
                    if(key == 'enable_click_sku') {
                        enabled = $scope.scan_pack.settings.enable_click_sku;
                        type = 'click_scan_enabled';
                    } else if(key == 'type_scan_code') {
                        enabled = $scope.scan_pack.settings.type_scan_code_enabled;
                        type = 'type_scan_enabled';
                    }
                    return {
                        type: type,
                        enabled: enabled
                    }
                }
            }
        });
    };

    $scope.change_post_scanning_opt = function(value) {
        $scope.scan_pack.settings.post_scanning_option = value;
        $scope.update_settings();
    };

    $scope.update_settings = function() {
        scanPack.settings.update($scope.scan_pack);
    };

	myscope.init();
}]);
