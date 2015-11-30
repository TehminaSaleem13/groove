groovepacks_directives.directive('groovDataGrid', ['$timeout', '$http', '$sce', 'settings', 'hotkeys', function ($timeout, $http, $sce, settings, hotkeys) {
  var default_options = function () {
    return {
      identifier: 'datagrid',
      select_all: false,
      invert: false,
      selectable: false,
      selections: {
        single_callback: function () {
        },
        multi_page: function () {
        },
        show_dropdown: false,
        selected_count: 0,
        unbind: false,
        show: function () {
        }
      },
      show_hide: false,
      editable: false,
      disable_global_edit: false,
      enable_edit: false,
      sortable: false,
      paginate: {
        show: false,
        total_items: 0,
        max_size: 12,
        current_page: 1,
        items_per_page: 10,
        callback: function () {
        }
      },
      sort_func: function () {
      },
      setup: {},
      all_fields: {}
    }
  };
  var default_field_options = function () {
    return {
      name: "field",
      class: "col-xs-2",
      hideable: true,
      hidden: false,
      transclude: '',
      model: 'row'
    }
  };
  return {
    restrict: "A",
    scope: {
      groovDataGrid: "=",
      rows: "=groovList"
    },
    templateUrl: "/assets/views/directives/datagrid.html",
    link: function (scope, el, attrs) {
      var myscope = {};
      scope.context_menu_event = function (event) {
        if (scope.options.show_hide) {
          if (typeof event == 'undefined' || typeof event['pointerType'] == 'undefined') {
            scope.context_menu.shown = !scope.context_menu.shown;
          }
          if (typeof event != "undefined") {
            event.preventDefault();
            if (typeof event['pointerType'] != 'undefined') {
              event = event.srcEvent;
            }
            var offset = el.offset();
            scope.context_menu.style = {left: event.pageX - offset.left, top: event.pageY - offset.top}
          }
        }
      };

      scope.show_hide = function (field) {
        field.hidden = !field.hidden;
        scope.update();
      };

      scope.check_uncheck = function (row, index, event) {
        if (scope.options.selectable) {
          scope.options.setup.select_all = false;
          row.checked = !row.checked;
          scope.options.selections.single_callback(row);
          if (event.shiftKey && myscope.last_clicked !== null) {
            event.preventDefault();
            var start = index;
            var end = myscope.last_clicked.index;
            if (myscope.last_clicked.page == scope.options.paginate.current_page) {
              if (index > myscope.last_clicked.index) {
                start = end;
                end = index;
              }
            } else {

              if (scope.options.paginate.current_page > myscope.last_clicked.page) {
                start = 0;
                end = index;
                scope.options.selections.multi_page(myscope.last_clicked, {
                  page: scope.options.paginate.current_page,
                  index: index
                }, row.checked);
              } else if (myscope.last_clicked.page > scope.options.paginate.current_page) {
                start = index;
                end = scope.rows.length - 1;
                scope.options.selections.multi_page({
                  page: scope.options.paginate.current_page,
                  index: index
                }, myscope.last_clicked, row.checked);
              }
            }
            for (var i = start; i <= end; i++) {
              scope.rows[i].checked = row.checked;
              scope.options.selections.single_callback(scope.rows[i]);
            }

          }
          myscope.last_clicked = {page: scope.options.paginate.current_page, index: index};
        }
      };
      scope.show_dropdown = function () {
        scope.dropdown.show = false;
        if (scope.options.selections.show_dropdown && !(scope.options.setup.select_all || scope.options.setup.inverted)) {
          $timeout.cancel(myscope.dropdown_promise);
          myscope.dropdown_promise = null;
          scope.dropdown.show = true;
        }
      };

      scope.update = function () {
        myscope.make_theads(scope.theads);
        settings.column_preferences.save(scope.options.identifier, scope.theads);
      };

      scope.compile = function (ind, field) {

        if (typeof scope.editable[field] == "undefined") {
          scope.editable[field] = {};
        }
        if (typeof scope.editable[field][ind] == "undefined") {
          scope.editable[field][ind] = $sce.trustAsHtml('<div groov-editable="options.editable" prop="{{field}}" ng-model="' + scope.options.all_fields[field].model + '" identifier="' + scope.options.identifier + '_list-' + field + '-' + ind + '">' + scope.options.all_fields[field].transclude + '</div>');
        }

        $timeout(function () {
          scope.$broadcast(scope.options.identifier + '_list-' + field + '-' + ind);
        }, 30);
      };

      myscope.make_theads = function (theads) {
        var shown = [];
        for (var i in scope.options.all_fields) {
          if (scope.options.all_fields.hasOwnProperty(i)) {
            if (!scope.options.all_fields[i].hidden) {
              shown.push(i);
            }
          }
        }
        scope.theads = theads.concat(shown).filter(function (elem, idx, arr) {
          return (shown.indexOf(elem) != -1 && arr.indexOf(elem) >= idx);
        });
        scope.dragOptions.reload = true;
      };

      myscope.invert_selection = function () {
        if (scope.options.invert === false) {
          for (var i = 0; i < scope.rows.length; i++) {
            scope.check_uncheck(scope.rows[i], i, {shiftKey: false});
          }
        } else {
          scope.options.invert(!scope.options.setup.inverted);
        }
        myscope.last_clicked = null;
      };

      myscope.update_paginate = function () {
        var options = default_options();
        jQuery.extend(true, options.paginate, scope.groovDataGrid.paginate);
        scope.options.paginate = options.paginate;
        myscope.last_clicked = null;
      };

      myscope.update_selections = function () {
        var options = default_options();
        jQuery.extend(true, options.selections, scope.groovDataGrid.selections);
        scope.options.selections = options.selections;
      };

      scope.start_dropdown_timer = function () {
        myscope.dropdown_promise = $timeout(function () {
          scope.dropdown.show = false
        }, 500);
      };
      myscope.init = function () {
        scope.theads = [];
        myscope.last_clicked = null;

        scope.editable = {};
        var options = default_options();
        jQuery.extend(true, options, scope.groovDataGrid);
        for (var i in scope.groovDataGrid.all_fields) {
          if (scope.groovDataGrid.all_fields.hasOwnProperty(i)) {
            options.all_fields[i] = default_field_options();
            options.all_fields[i].editable = (options.disable_global_edit == false && options.editable != false);
            options.all_fields[i].draggable = (options.draggable != false);
            options.all_fields[i].sortable = (options.sortable != false);
            angular.extend(options.all_fields[i], scope.groovDataGrid.all_fields[i]);
            if (options.all_fields[i].transclude !== '') {
              options.all_fields[i].transclude = $sce.trustAsHtml(scope.groovDataGrid.all_fields[i].transclude);
            }
            if (options.all_fields[i].enable_edit == true) {
              options.all_fields[i].editable = true;
            }
            scope.theads.push(i);
          }
        }
        if (angular.isObject(scope.groovDataGrid['setup'])) {
          options.setup = scope.groovDataGrid.setup;
        }
        scope.context_menu = {
          shown: false,
          style: {}
        };
        scope.options = options;
        scope.dragOptions = {
          update: scope.update,
          enabled: scope.options.draggable,
          reload: false
        };
        scope.dropdown = {
          show: false
        };
        scope.custom_identifier = scope.options.identifier + Math.floor(Math.random() * 1000);

        settings.column_preferences.get(scope.options.identifier).success(function (data) {
          if (data.status) {
            var theads = [];
            if (data.data && typeof data.data['theads'] != "undefined" && data.data.theads) {
              theads = data.data.theads;
              for (var i in scope.options.all_fields) {
                if (scope.options.all_fields.hasOwnProperty(i)) {
                  if (scope.options.all_fields[i].hideable) {
                    scope.options.all_fields[i].hidden = true;
                  }
                  if (theads.indexOf(i) != -1) {
                    scope.options.all_fields[i].hidden = false;
                  }
                }
              }
            }
            myscope.make_theads(theads);
          }
        });
        if (scope.options.selectable && !scope.options.selections.unbind) {
          hotkeys.add({
            combo: 'mod+i',
            callback: myscope.invert_selection
          });
        }
        if (typeof scope.groovDataGrid['paginate'] != "undefined") {
          scope.$watch('groovDataGrid.paginate', myscope.update_paginate, true);
          scope.$watch('options.paginate.current_page', scope.options.paginate.callback);
        }
        if (typeof scope.groovDataGrid['selections'] != "undefined" && scope.groovDataGrid.selections.show_dropdown) {
          scope.$watch('groovDataGrid.selections', myscope.update_selections, true);
        }
      };

      myscope.init();
    }
  };
}]);
