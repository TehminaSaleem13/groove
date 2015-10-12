var groovepacks_admin = angular.module('groovepacks_admin', ['groovepacks.filters', 'groovepacks.services',
  'groovepacks.directives', 'groovepacks_admin.controllers', 'ui.sortable', 'pasvaz.bindonce', 'ngCookies',
  'ct.ui.router.extras', 'ngAnimate', 'ui.bootstrap', 'cfp.hotkeys',
  'angular-loading-bar', 'pascalprecht.translate', 'toggle-switch', 'ngTouch',
  'hmTouchEvents', 'btford.socket-io', 'textAngular', 'ngClipboard', 'ng-rails-csrf']);
var groovepacks_admin_controllers = angular.module('groovepacks_admin.controllers', []);

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
