
var groovepacks = angular.module('groovepacks', ['groovepacks.filters', 'groovepacks.services',
	 'groovepacks.directives', 'groovepacks.controllers','ui.sortable','pasvaz.bindonce', 'ngCookies',
	 'ct.ui.router.extras','ngAnimate', 'ui.bootstrap','cfp.hotkeys',
   'angular-loading-bar','pascalprecht.translate','toggle-switch','ngTouch',
   'hmTouchEvents','btford.socket-io','textAngular', 'ngClipboard', 'highcharts-ng', 'angularDc']);
var groovepacks_controllers = angular.module('groovepacks.controllers', []);
var groovepacks_filters = angular.module('groovepacks.filters', []);
var groovepacks_services = angular.module('groovepacks.services', []);
var groovepacks_directives = angular.module('groovepacks.directives', []);

String.prototype.chunk = function(size) {
    return [].concat.apply([],
        this.split('').map(function(x,i){
            return i%size ? [] : this.slice(i,i+size)
        }, this)
    )
};

String.prototype.trimmer = function (chr) {
    return this.replace((!chr) ? new RegExp('^\\s+|\\s+$', 'g') : new RegExp('^'+chr+'+|'+chr+'+$', 'g'), '');
};
