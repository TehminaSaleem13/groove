groovepacks_controllers. 
controller('generalSettingsCtrl', [ '$scope', '$http', '$timeout', '$location', '$state', '$cookies', 'generalsettings', 'groov_translator',
function( $scope, $http, $timeout, $location, $state, $cookies, generalsettings, groov_translator) {

    var myscope = {};


    myscope.init = function() {
        $scope.setup_page('system','general');
        $scope.translations = {
            "headings": {
                "inventory": "",
                "conf_notif": "",
                "printing_option": ""
            },
            "labels": {
                "inventory_tracking": "",
                "low_inventory_alert_email": "",
                "time_to_send_email": "",
                "send_email_on": "",
                "mon": "",
                "tue": "",
                "wed": "",
                "thu": "",
                "fri": "",
                "sat": "",
                "sun": "",
                "default_low_inventory_alert_limit": "",
                "hold_orders_due_to_inventory": "",
                "conf_req_on_notes_to_packer": "",
                "always": "",
                "optional": "",
                "never": "",
                "send_email_for_packer_notes": "",
                "email_address": "",
                "packing_slip_size": "",
                "packing_slip_orientation": "",
                "portrait": "",
                "landscape": "",
                "packing_slip_message_to_customer": ""
            },
            "tooltips": {
                "inventory_tracking": "",
                "low_inventory_alert_email": "",
                "default_low_inventory_alert_limit": "",
                "hold_orders_due_to_inventory": "",
                "conf_req_on_notes_to_packer": "",
                "send_email_for_packer_notes": "",
                "packing_slip_size": "",
                "packing_slip_message_to_customer": ""
            }
        };
        groov_translator.translate('settings.system.general',$scope.translations);

        $scope.show_button = false;
        $scope.generalsettings = generalsettings.model.get();
        generalsettings.single.get($scope.generalsettings);

    };

    $scope.change_opt = function(key,value) {
        $scope.generalsettings.single[key] = value;
        $scope.update_settings();
    };

    $scope.update_settings = function() {
        $scope.show_button = false;
        generalsettings.single.update($scope.generalsettings);
    };

	myscope.init();
}]);
