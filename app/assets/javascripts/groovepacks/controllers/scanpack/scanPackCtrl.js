groovepacks_controllers.
  controller('scanPackCtrl', ['$scope', '$http', '$timeout', '$stateParams', '$location', '$state', '$cookies', 'scanPack', 'generalsettings', 'groov_audio',
    function ($scope, $http, $timeout, $stateParams, $location, $state, $cookies, scanPack, generalsettings, groov_audio) {
      var myscope = {
        gen_setting_loaded: 0,
        scanpack_setting_loaded: 0
      };
      $scope.init = function () {
        myscope.callback = function () {
          return true;
        };
        if (myscope.check_reload_settings()) {
          myscope.init();
        }
        myscope.callbacks = {};
        $scope.current_state = $state.current.name;
        if (typeof $scope.data == "undefined") {
          $scope.data = {};
        }
        $scope.data.input = "";
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
                $scope.trigger_scan_message('order_complete');
              }
              $state.go(data.data.next_state, data.data);
            }
          }
        }
      };

      $scope.input_enter = function (event) {
        if (event.which != '13') return;
        if (!myscope.callback()) return;
        var id = null;
        if (typeof $scope.data.order.id !== "undefined") {
          id = $scope.data.order.id;
        }
        if ($scope.current_state == 'scanpack.rfp.default') {
          scanPack.input_scan_happend = true
        }
        myscope.last_scanned_barcode = $scope.data.input;
        scanPack.input($scope.data.input, $scope.current_state, id).success($scope.handle_scan_return);
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
              if (typeof myscope.sounds[i] == 'undefined') {
                myscope.sounds[i] = groov_audio.load($scope.scan_pack.settings[i + '_sound_url'], $scope.scan_pack.settings[i + '_sound_vol']);
              }
            }
          });
          myscope.scanpack_setting_loaded = (new Date).getTime();
        });
      }
    }]);
