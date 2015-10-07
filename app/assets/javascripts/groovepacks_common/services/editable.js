groovepacks_services.factory('editable', ['$rootScope', function ($rootScope) {

  var editing = false;
  var config = function () {
    return {
      class: 'span3',
      array: false,
      update: function () {
      },
      sortableOptions: {},
      elements: {},
      functions: {}
    };
  };
  var set_editing = function (value) {
    editing = value;
    $rootScope.$emit("editing-a-var", {ident: value});
  };

  var unset_editing = function () {
    editing = false;
    $rootScope.$emit("editing-a-var", {ident: false});
  };

  var force_reset = function () {
    editing = false;
    $rootScope.$emit("force-exit-edit-var");
  };

  var editing_status = function () {
    return editing;
  };

  return {
    default: config,
    set: set_editing,
    unset: unset_editing,
    status: editing_status,
    force_exit: force_reset
  }
}]);
