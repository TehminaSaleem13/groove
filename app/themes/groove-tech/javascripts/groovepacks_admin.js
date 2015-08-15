var groovepacks_admin = angular.module('groovepacks_admin', ['groovepacks_admin.filters', 'groovepacks_admin.services',
  'groovepacks_admin.directives', 'groovepacks_admin.controllers', 'ui.sortable', 'pasvaz.bindonce', 'ngCookies',
  'ct.ui.router.extras', 'ngAnimate', 'ui.bootstrap', 'cfp.hotkeys',
  'angular-loading-bar', 'pascalprecht.translate', 'toggle-switch', 'ngTouch',
  'hmTouchEvents', 'btford.socket-io', 'textAngular', 'ngClipboard', 'ng-rails-csrf']);
var groovepacks_admin_controllers = angular.module('groovepacks_admin.controllers', []);
var groovepacks_admin_filters = angular.module('groovepacks_admin.filters', []);
var groovepacks_admin_services = angular.module('groovepacks_admin.services', []);
var groovepacks_admin_directives = angular.module('groovepacks_admin.directives', []);

String.prototype.chunk = function (size) {
  return [].concat.apply([],
    this.split('').map(function (x, i) {
      return i % size ? [] : this.slice(i, i + size)
    }, this)
  )
};

String.prototype.trimmer = function (chr) {
  return this.replace((!chr) ? new RegExp('^\\s+|\\s+$', 'g') : new RegExp('^' + chr + '+|' + chr + '+$', 'g'), '');
};
