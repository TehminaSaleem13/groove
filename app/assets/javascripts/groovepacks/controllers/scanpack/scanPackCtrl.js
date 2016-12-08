groovepacks_controllers.
  controller('scanPackCtrl', ['$scope', '$http', '$timeout', '$stateParams', '$location', '$state', '$cookies', 'scanPack', 'generalsettings', 'groov_audio', '$window', '$modal', '$sce', '$interval',
    function ($scope, $http, $timeout, $stateParams, $location, $state, $cookies, scanPack, generalsettings, groov_audio, $window, $modal, $sce, $interval) {
      var myscope = {
        gen_setting_loaded: 0,
        scanpack_setting_loaded: 0
      };
      $scope.init = function () {
        myscope.callback = function () {
          return true;
        };
        if (myscope.check_reload_settings()) {
          var last_scanned_item = myscope.last_scanned_barcode;
          myscope.init();
          myscope.last_scanned_barcode = last_scanned_item;
        }
        myscope.callbacks = {};
        $scope.current_state = $state.current.name;
        if (typeof $scope.data == "undefined") {
          $scope.data = {};
        }
        $scope.data.input = "";
        window.scope = $scope;
        //console.log($scope.current_state);
      };

      $scope.set = function (key, val) {
        $scope.data[key] = val;
      };

      $scope.trigger_scan_message = function (type) {

        $scope.scan_pack_state = type;
        if (['success', 'fail', 'order_complete'].indexOf(type) != -1) {
          var object = $scope.scan_pack.scan_states[type];
          if (object.image.enabled) {
            $timeout(function () {
              $scope.scan_pack_state = 'none';
            }, object.image.time);
          }
          if (object.sound.enabled) {
            groov_audio.play(myscope.sounds[type]);
          }
        }
      };

      $scope.get_last_scanned = function () {
        return myscope.last_scanned_barcode;
      };

      $scope.reg_callback = function (func) {
        if (typeof func == 'function') {
          myscope.callback = func;
        }
      };
      $scope.handle_scan_return = function (data) {
        if ((data.data != "undefined") && (data.data.order!=undefined) && (data.data.order.store_type != undefined)) {
          $scope.store_type = data.data.order.store_type
        } 
        $scope.set('raw', data);
        if (typeof data.data != "undefined") {
          if (typeof data.data.order != "undefined") {
            $scope.set('order', data.data.order);
            $scope.set('scan_pack_settings', data.data.scan_pack_settings);
          }
          if (typeof data.data.next_state != "undefined") {
            if ($state.current.name == data.data.next_state) {
              if (data.data.next_state == 'scanpack.rfp.default') {
                $scope.trigger_scan_message((data.status) ? 'success' : 'fail');
                $scope.focus_search();
              }
              $scope.$broadcast('reload-scanpack-state');
            } else {
              if (data.data.order_complete) {
                if ($scope.data.order.store_type=="ShippingEasy" && ($scope.data != "undefined") && ($scope.data.order!=undefined) && $scope.data.order.popup_shipping_label==true){
                  if($scope.data.order.shipment_id != null){
                    var shippingeasy_url = $sce.trustAsResourceUrl("http://app.shippingeasy.com/shipments/" + parseInt($scope.data.order.shipment_id) + "/edit");
                    $scope.open_popup(shippingeasy_url);
                  } else {
                    scanPack.getshipment($scope.data.order.store_id, $scope.data.order.store_order_id).success(function (d) {
                      if(d.shipment_id != null){
                        var shippingeasy_url = $sce.trustAsResourceUrl("http://app.shippingeasy.com/shipments/" + parseInt(d.shipment_id) + "/edit");
                        $scope.open_popup(shippingeasy_url);
                      };
                    });
                  };
                } else {
                  $scope.trigger_scan_message('order_complete');
                }
                if ($scope.data.order.store_type == "Shipstation API 2" && !!window.chrome && !!window.chrome.webstore && $scope.data.order.use_chrome_extention==true){
                  $(".content_for_extension").attr("data-switch_back",  [$scope.data.order.switch_back_button, $scope.data.order.auto_click_create_label]);
                  $(".content_for_extension").text($scope.data.order.increment_id);
                }
              }
            }
            $state.go(data.data.next_state, data.data);
          }
        }
      };

      $scope.open_popup = function (url) {
        var w = 1240;
        var h = 600;
        var left_adjust = angular.isDefined($window.screenLeft) ? $window.screenLeft : $window.screen.left;
        var top_adjust = angular.isDefined($window.screenTop) ? $window.screenTop : $window.screen.top;
        var width = $window.innerWidth ? $window.innerWidth : $window.document.documentElement.clientWidth ? $window.document.documentElement.clientWidth : $window.screen.width;
        var height = $window.innerHeight ? $window.innerHeight : $window.document.documentElement.clientHeight ? $window.document.documentElement.clientHeight : $window.screen.height;
        var left = ((width / 2) - (w / 2)) + left_adjust;
        var top = ((height / 2) - (h / 2)) + top_adjust;
        var popup = $window.open(url, '', "top=" + top + ", left=" + left + ", width=" + w + ", height=" + h);
        var interval = 1000;
        var i = $interval(function () {
          try {
            if (popup == null || popup.closed) {
              $interval.cancel(i);
              $scope.trigger_scan_message('order_complete');
            }
          } catch (e) {
            console.error(e);
          }
        }, interval);
      };

      $scope.input_enter = function (event) {
        if (event.which != '13') return;
        if ($scope.current_state == 'scanpack.rfp.default' && $scope.scan_pack.settings.post_scan_pause_enabled) {
          window.setTimeout(function() {
            myscope.start_scanning(event);
          }, $scope.scan_pack.settings.post_scan_pause_time*1000);
        } else {
          myscope.start_scanning(event);
        }
      };

      myscope.start_scanning = function(event) {
        if (!myscope.callback()) return;
        var id = null;
        if (typeof $scope.data.order.id !== "undefined") {
          id = $scope.data.order.id;
        }
        if ($scope.current_state == 'scanpack.rfp.default') {
          scanPack.input_scan_happend = true
        }
        if ($scope.data.input!=undefined && $scope.data.input!='') {
          myscope.last_scanned_barcode = $scope.data.input;
        }
        $window.increment_id = $scope.data.order.increment_id;
        scanPack.input($scope.data.input, $scope.current_state, id).success($scope.handle_scan_return);
          // scanPack.update_chrome_tab();
        // var barcodes = [];
        // if (typeof $scope.data.order.next_item != "undefined" ){
        //   var values = $scope.data.order.next_item.barcodes;
        //   angular.forEach(values, function(value) { this.push(value.barcode.toLowerCase()); }, barcodes);
        // };
        // if (barcodes.includes($scope.data.input.toLowerCase()) || ($scope.current_state != 'scanpack.rfp.default')) {
        //   $window.increment_id = $scope.data.order.increment_id;
        //   scanPack.input($scope.data.input, $scope.current_state, id).success($scope.handle_scan_return);
        // } else {
        //   $scope.trigger_scan_message('fail');
        // }      
      };

      myscope.check_reload_settings = function () {
        var cur_time = (new Date).getTime();
        return !(((cur_time - myscope.gen_setting_loaded) < 60000) && ((cur_time - myscope.scanpack_setting_loaded) < 60000));
      };

      myscope.init = function () {
        $scope.scan_pack = scanPack.settings.model();
        $scope.general_settings = generalsettings.model.get();
        myscope.last_scanned_barcode = '';
        generalsettings.single.get($scope.general_settings).success(function () {
          myscope.gen_setting_loaded = (new Date).getTime();
        });
        if (typeof myscope['sounds'] == 'undefined') {
          myscope.sounds = {};
        }
        //$scope.scan_pack_state = 'none';
        scanPack.settings.get($scope.scan_pack).success(function () {
          angular.forEach(['success', 'fail', 'order_complete'], function (i) {
            if ($scope.scan_pack.settings['show_' + i + '_image']) {
              $scope.scan_pack.scan_states[i].image.enabled = $scope.scan_pack.settings['show_' + i + '_image']; 
              $scope.scan_pack.scan_states[i].image.src = $scope.scan_pack.settings[i + '_image_src'];
              $scope.scan_pack.scan_states[i].image.time = $scope.scan_pack.settings[i + '_image_time'] * 1000;
            }
            if ($scope.scan_pack.settings['play_' + i + '_sound']) {
              $scope.scan_pack.scan_states[i].sound.enabled = $scope.scan_pack.settings['play_' + i + '_sound'];
              if (typeof myscope.sounds[i] == 'undefined'){
                myscope.sounds[i] = groov_audio.load($scope.scan_pack.settings[i + '_sound_url'], $scope.scan_pack.settings[i + '_sound_vol']);
              }
            }
          });
          myscope.scanpack_setting_loaded = (new Date).getTime();
        });
      }

      $scope.show_video = function(){
        var video_modal_popup = $modal.open({
          template: '<iframe width="560" height="315" src="https://www.youtube.com/embed/GAhFG-CPTJ0?rel=0" frameborder="0" allowfullscreen></iframe>', 
          windowClass: 'app-modal-video-window'
        });
      };
    }]);

