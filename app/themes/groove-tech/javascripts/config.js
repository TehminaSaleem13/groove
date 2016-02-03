groovepacks.config(['$stateProvider', '$urlRouterProvider', '$httpProvider', 'hotkeysProvider', 'cfpLoadingBarProvider', '$translateProvider', '$urlMatcherFactoryProvider', 'ngClipProvider',
  function ($stateProvider, $urlRouterProvider, $httpProvider, hotkeysProvider, cfpLoadingBarProvider, $translateProvider, $urlMatcherFactoryProvider, ngClipProvider) {

    ngClipProvider.setPath("/swf/ZeroClipboard.swf");

    $urlRouterProvider.otherwise("/home");
    $urlRouterProvider.when('/scanandpack/rfp', '/scanandpack');
    $urlRouterProvider.when('/settings', '/settings/stores');
    $urlRouterProvider.when('/settings/system', '/settings/system/general');

    $urlMatcherFactoryProvider.strictMode(false);
    $httpProvider.defaults.useXDomain = true;
    $httpProvider.defaults.withCredentials = true;
    delete $httpProvider.defaults.headers.common["X-Requested-With"];
    $httpProvider.defaults.headers.common["Accept"] = "application/json";
    $httpProvider.defaults.headers.common["Content-Type"] = "application/json";
    $stateProvider
      .state('home', {url: '/home'})
      .state('orders', {url: '/orders', templateUrl: '/assets/views/showorders.html', controller: 'ordersCtrl'})
      .state('orders.filter', {
        url: '/{filter:all|awaiting|onhold|serviceissue|cancelled|scanned}', params: {filter: 'awaiting'},
        template: "<div ui-view></div>", abstract: true
      })
      .state('orders.filter.page', {
        url: '/{page:[0-9]+}', template: "<div ui-view></div>", params: {page: '1'},
        controller: 'ordersFilterCtrl'
      })
      .state('orders.filter.page.single', {
        url: '/{order_id:[0-9]+}', template: "<div ui-view></div>",
        controller: 'ordersSingleCtrl'
      })

      .state('products', {url: '/products', templateUrl: '/assets/views/showproducts.html', controller: 'productsCtrl'})
      .state('products.type', {
        url: '/{type:product|kit}',
        params: {type: 'product'},
        template: "<div ui-view></div>",
        abstract: true
      })
      .state('products.type.filter', {
        url: '/{filter:all|active|inactive|new}', params: {filter: 'active'}, template: "<div ui-view></div>",
        abstract: true
      })
      .state('products.type.filter.page', {
        url: '/{page:[0-9]+}', params: {page: '1'}, template: "<div ui-view></div>",
        controller: 'productsFilterCtrl'
      })
      .state('products.type.filter.page.single', {
        url: '/{product_id:[0-9]+}', params: {new_product: {value: false}}, template: "<div ui-view></div>",
        controller: 'productsSingleCtrl'
      })

      .state('scanpack', {
        url: '/scanandpack', templateUrl: '/assets/views/scanpack/base.html', controller: 'scanPackCtrl'
        , abstract: true
      })
      .state('scanpack.rfo', {url: '', templateUrl: '/assets/views/scanpack/multi.html', controller: 'scanPackRfoCtrl'})
      .state('scanpack.rfp', {
        url: '/rfp/:order_num', templateUrl: "/assets/views/scanpack/rfpbase.html", controller: 'scanPackRfpCtrl',
        abstract: true
      })
      .state('scanpack.rfp.default', {
        url: '', controller: 'scanPackRfpDefaultCtrl',
        templateUrl: '/assets/views/scanpack/rfpdefault.html'
      })
      .state('scanpack.rfp.recording', {
        url: '/recording', templateUrl: '/assets/views/scanpack/multi.html',
        controller: 'scanPackRecordingCtrl'
      })
      .state('scanpack.rfp.verifying', {
        url: '/verifying', templateUrl: '/assets/views/scanpack/multi.html',
        controller: 'scanPackRecordingCtrl'
      })
      .state('scanpack.rfp.no_tracking_info', {
        url: '/no_tracking_info', templateUrl: '/assets/views/scanpack/multi.html',
        controller: 'scanPackRecordingCtrl'
      })
      .state('scanpack.rfp.no_match', {
        url: '/no_match', templateUrl: '/assets/views/scanpack/multi.html',
        controller: 'scanPackRecordingCtrl'
      })
      .state('scanpack.rfp.product_edit', {
        url: '/product_edit', templateUrl: '/assets/views/scanpack/productedit.html',
        controller: 'scanPackProductEditCtrl'
      })
      .state('scanpack.rfp.product_edit.single', {
        url: '/{product_id:[0-9]+}',
        template: '',
        controller: 'productsSingleCtrl'
      })
      .state('scanpack.rfp.confirmation', {
        url: '/confirmation', controller: 'scanPackConfCtrl',
        templateUrl: '/assets/views/scanpack/multi.html', abstract: true
      })
      .state('scanpack.rfp.confirmation.order_edit', {url: '/order_edit'})
      .state('scanpack.rfp.confirmation.product_edit', {url: '/product_edit'})
      .state('scanpack.rfp.confirmation.cos', {url: '/cos'})

      .state('settings', {
        url: '/settings',
        templateUrl: '/assets/views/settings/base.html',
        controller: 'settingsCtrl',
        abstract: true
      })

      //.state('settings.detailed_import', {url:'/detailed_import',templateUrl:'/assets/views/settings/csv_detailed.html',
      //    controller:'csvDetailed'})

      .state('settings.users', {
        url: '/users',
        templateUrl: '/assets/views/settings/users.html',
        controller: 'usersCtrl'
      })
      .state('settings.users.create', {url: '/create', controller: 'usersSingleCtrl'})
      .state('settings.users.single', {url: '/{user_id:[0-9]+}', controller: 'usersSingleCtrl'})
      .state('settings.stores', {
        url: '/stores',
        templateUrl: '/assets/views/settings/stores.html',
        controller: 'storesCtrl'
      })
      .state('settings.stores.ebay', {
        url: '/ebay?ebaytkn&tknexp&username&redirect&editstatus&name&status&storetype&storeid&inventorywarehouseid&importimages&importproducts&messagetocustomer&tenantname',
        controller: 'storeSingleCtrl'
      })
      .state('settings.stores.create', {url: '/create', controller: 'storeSingleCtrl'})
      .state('settings.stores.single', {url: '/{storeid:[0-9]+}', controller: 'storeSingleCtrl'})

      .state('settings.system', {url: '/system', template: '<div ui-view></div>', abstract: true})
      .state('settings.system.general', {
        url: '/general', templateUrl: '/assets/views/settings/system/general.html',
        controller: 'generalSettingsCtrl'
      })
      .state('settings.system.scan_pack', {
        url: '/scan_pack', templateUrl: '/assets/views/settings/system/scan_pack.html',
        controller: 'scanPackSettingsCtrl'
      })
      .state('settings.system.warehouses', {
        url: '/warehouses', templateUrl: '/assets/views/settings/system/warehouses.html',
        controller: 'warehousesCtrl'
      })

      .state('settings.accounts', {url: '/accounts', template: '<div ui-view></div>', abstract: true})
      .state('settings.accounts.card_details', {
        url: '/card_details', templateUrl: '/assets/views/settings/accounts/payment_details.html',
        controller: 'paymentsCtrl'
      })

      .state('settings.export', {url: '/export', template: '<div ui-view></div>', abstract: true})
      .state('settings.export.backup_restore', {
        url: '/backup_restore',
        templateUrl: '/assets/views/settings/export/backup.html',
        controller: 'showBackupCtrl'
      })
      .state('settings.export.order_exception', {
        url: '/order_exception',
        templateUrl: '/assets/views/settings/export/order_exceptions.html',
        controller: 'exportOrderExceptionCtrl'
      })
      .state('settings.export.order_export', {
        url: '/order_export',
        templateUrl: '/assets/views/settings/export/order_export.html',
        controller: 'orderExportCtrl'
      })
      .state('settings.export.serial_export', {
        url: '/serial_export',
        templateUrl: '/assets/views/settings/export/order_serials.html',
        controller: 'exportOrderExceptionCtrl'
      });

    hotkeysProvider.cheatSheetHotkey = ['mod+f1', 'g', 'G'];
    hotkeysProvider.cheatSheetDescription = '(or \'g\') Show / hide this help menu';
    cfpLoadingBarProvider.includeSpinner = false;
    $translateProvider.useStaticFilesLoader({
      prefix: '/assets/translations/locale-',
      suffix: '.json'
    });
    $translateProvider.preferredLanguage('en').fallbackLanguage('en');
  }]).run(['$rootScope', '$state', '$urlRouter', '$timeout', 'auth', 'hotkeys', 'logger',
  function ($rootScope, $state, $urlRouter, $timeout, auth, hotkeys, logger) {
    $rootScope.$on('$stateChangeStart', function (e, to, toParams, from, fromParams) {

      var register_hot_keys = function () {
        if (!hotkeys.get('ctrl+alt+e')) {
          hotkeys.add({
            combo: 'ctrl+alt+e',
            description: 'Opens log',
            allowIn: ['INPUT', 'SELECT', 'TEXTAREA'],
            callback: function (event, hotkey) {
              event.preventDefault();
              var current_user = auth.get();
              if (current_user != null &&
                typeof(current_user) != {} &&
                current_user.role.name == "Super Super Admin") {
                logger.open();
              }
            }
          });
        }
      }

      if (jQuery.isEmptyObject(auth.get())) {
        if (!from.abstract || from.name == '') {
          e.preventDefault();
        }
        auth.check().then(function () {
          var result = auth.prevent(to.name, toParams);
          if (result && result.to) {
            register_hot_keys();
            $state.go(result.to, result.params);
          } else if (!jQuery.isEmptyObject(auth.get())) {
            $urlRouter.sync();
          }
        })
      } else {
        var result = auth.prevent(to.name, toParams);
        register_hot_keys();
        if (result && result.to) {
          e.preventDefault();
          $state.go(result.to, result.params);
        } else {
          if (to.name === 'products' || to.name === 'products.type' || to.name === 'products.type.filter') {
            e.preventDefault();
            $state.go('products.type.filter.page');
          } else if (to.name === 'orders' || to.name === 'orders.filter') {
            e.preventDefault();
            $state.go('orders.filter.page');

          }
        }
      }

    });
  }]);
