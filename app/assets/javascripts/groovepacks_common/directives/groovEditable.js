groovepacks_directives.directive('groovEditable', ['$timeout', 'editable', '$rootScope', function ($timeout, editable, $rootScope) {
  return {
    restrict: "A",
    transclude: true,
    templateUrl: "/assets/views/directives/editable.html",
    scope: {
      ngModel: "=",
      prop: "@",
      identifier: "@",
      groovEditable: "=",
      position: "@"
    },
    link: function (scope, el, attrs, ctrl, transclude) {
      var myscope = {};
      scope.save_node = function (blur) {
        editable.unset();
        blur = (typeof blur == "boolean") ? blur : false;
        if (scope.editing != -1) {
          if (scope.editable.array) {
            if (typeof scope.ngModel[scope.editing] !== "undefined") {
              if (scope.ngModel[scope.editing][scope.prop] == "") {
                scope.remove_node(scope.editing);
              }
            }
          }
          scope.editable.update(scope.ngModel, scope.prop);
        }
        scope.editing = -1;
        if (!blur) {
          scope.focus_input();
        }
      };

      scope.add_node = function () {
        if (editable.status() == false) {
          if (scope.editable.array) {
            var mytemp = {};
            mytemp[scope.prop] = "";
            scope.ngModel.push(mytemp);
            scope.edit_node(-1);
          } else {
            scope.edit_node();
          }
        }
      };
      scope.remove_node = function (index) {
        if (editable.status() == false) {
          if (scope.editable.array) {
            scope.ngModel.splice(index, 1);
            scope.editable.update(scope.ngModel, scope.prop);
            scope.editing = -1;
          }
        }
        //scope.focus_input();
      };

      scope.edit_node = function (index) {
        if (editable.status() == false) {
          editable.set(scope.custom_identifier);

          if (scope.editable.array) {
            if (index == -1) {
              index = scope.ngModel.length - 1;
            }
            if (scope.editing != -1 && scope.editing != index) {
              scope.save_node();
            }
            scope.editing = index;
          } else {
            scope.editing = 1;
          }
          $timeout(scope.focus_input, 10);
        }
      };


      scope.focus_event = function () {
        scope.editable_class = scope.editable.class + " input-text uneditable-input input-text-hover";
        scope.tag_class = "tag-bubble tag-bubble-input span3 input-text";
        scope._focus_lost = false;
      };
      scope.focus_input = function () {
        $timeout(function () {
          $("#" + scope.custom_identifier + scope.identifier + "-" + scope.prop + "-" + scope.editing).focus();
          $("#" + scope.custom_identifier + scope.identifier + "-" + scope.prop + "-" + scope.editing).select();

        }, 10);
      };
      scope.blur_event = function () {
        scope._focus_lost = true;
        scope.editable_class = scope.editable.class + " input-text uneditable-input";
        scope.tag_class = "tag-bubble false-tag-bubble tag-bubble-input span3 input-text";
      };
      scope.handle_key_event = function (event) {
        if (event.which == 13 || event.which == 9) {
          event.preventDefault();
          scope.save_node();
        }
      };


      myscope.prevent_and_edit = function (event) {
        event.preventDefault();
        event.stopPropagation();
        scope.edit_node();
      };

      myscope.prevent_and_add = function (event) {
        event.preventDefault();
        event.stopPropagation();
        if (scope.editing == -1) {
          scope.add_node();
        }
      };

      myscope.setup_editable = function () {
        scope.editable = editable.default();
        angular.extend(scope.editable, scope.groovEditable);
        if (typeof scope.editable.elements[scope.prop] == "undefined") {
          scope.editable.elements[scope.prop] = {type: 'text', value: ''};
        }
        if (typeof scope.editable.functions[scope.prop] == "undefined") {
          scope.editable.functions[scope.prop] = function () {
          };
        }
        if (scope.editable.array) {
          el.bind('dblclick', myscope.prevent_and_add);
          el.bind('contextmenu', myscope.prevent_and_add);
        } else {
          el.bind('dblclick', myscope.prevent_and_edit);
          el.bind('contextmenu', myscope.prevent_and_edit);
        }
      };

      myscope.init = function () {
        scope.is_transcluded = false;
        scope.custom_identifier = "editable-" + Math.floor(Math.random() * 1000) + "-";
        scope.single_editable_id = scope.custom_identifier + scope.identifier + "-" + scope.prop + "-1";
        scope.editing = -1;
        scope.disabled = false;
        scope._focus_lost = false;
        myscope.setup_editable();
        scope.function = scope.editable.functions[scope.prop];
        scope.input = scope.editable.elements[scope.prop];
        scope.editable_class = scope.editable.class + ' input-text uneditable-input';
        scope.tag_class = 'tag-bubble false-tag-bubble tag-bubble-input span3 input-text';


        transclude(scope, function (clone) {
          scope.is_transcluded = clone.text().trim().length ? true : false;
        });
        scope.$watch('_focus_lost', function () {
          if (scope._focus_lost) {
            $timeout(function () {
              if (scope._focus_lost) {
                scope.save_node(true);
              }
            }, 500);
          }
        });

        $rootScope.$on('force-exit-edit-var', function () {
          scope.disabled = false;
          scope._focus_lost = false;
          scope.save_node(true);
        });
        $rootScope.$on("editing-a-var", function (event, data) {
          scope.disabled = !(data.ident === false || data.ident === scope.custom_identifier);
        });

        scope.$on(scope.identifier, scope.edit_node);
      };

      myscope.init();
    }
  };
}]);
