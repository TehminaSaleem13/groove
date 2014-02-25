groovepacks_directives.directive('groovEditable', ['$timeout',function ($timeout) {
        var groovEditableConfig = function () {
            return {
                class:'span3',
                array:false,
                update: function() {},
                sortableOptions:{},
                elements: {},
                functions: {}
            };
        }

    return {
        restrict:"A",
        transclude: true,
        templateUrl:"/assets/partials/editable.html",
        scope: {
            ngModel: "=",
            prop: "@",
            identifier:"@",
            groovEditable: "="
        },
        link: function(scope,el,attrs,ctrl,transclude) {




            scope.save_node = function(blur) {
                blur = (typeof blur == "boolean")? blur : false;
                if(scope.editing != -1) {
                    if(scope.editable.array) {
                        if(scope.ngModel[scope.editing][scope.prop] == "" && blur) {
                            scope.remove_node(scope.editing);
                        }
                    }
                    $timeout(function() {
                        scope.editable.update(scope.ngModel,scope.prop);
                    },30);
                }
                scope.editing = -1;
                if(!blur) {
                    scope.focus_input();
                }
            }

            scope.add_node  = function () {
                if(scope.editable.array) {
                    mytemp = {};
                    mytemp[scope.prop] = "";
                    scope.ngModel.push(mytemp);
                    scope.edit_node(-1);
                } else {
                    scope.edit_node();
                }

            }
            scope.remove_node = function(index) {
                if(scope.editable.array) {
                    scope.ngModel.splice(index,1);
                    scope.editable.update(scope.ngModel,scope.prop);
                    scope.editing = -1;
                }
                //scope.focus_input();
            }

            scope.edit_node = function(index) {
                if(scope.editable.array) {
                    if(index == -1) {
                        index = scope.ngModel.length-1;
                    }
                    if(scope.editing != -1) {
                        scope.save_node();
                    }
                    scope.editing = index;
                } else {
                    scope.editing =  1;
                }
                scope.focus_input();
            }


            scope.focus_event = function() {
                scope.editable_class =  scope.editable.class +" input-text uneditable-input input-text-hover";
                scope.tag_class = "tag-bubble tag-bubble-input span3 input-text";
                scope._focus_lost=false;
            }
            scope.focus_input = function() {
                $timeout(function(){
                    $("#editable-"+scope.identifier+"-"+scope.prop+"-"+scope.editing).focus();
                },200);
            }
            scope.blur_event = function() {
                scope._focus_lost=true;
                scope.editable_class =  scope.editable.class+" input-text uneditable-input";
                scope.tag_class = "tag-bubble false-tag-bubble tag-bubble-input span3 input-text";
            }
            scope.handle_key_event =  function(event) {
                if(event.which == 13 || event.which == 188 || event.which == 9) {
                    event.preventDefault();
                    scope.save_node();
                }
            }


            scope._prevent_and_edit = function (event) {
                event.preventDefault();
                event.stopPropagation();
                scope.edit_node();
            }

            scope._prevent_and_add = function(event) {
                event.preventDefault();
                event.stopPropagation();
                if(scope.editing == -1) {
                    scope.add_node();
                }
            }

            scope._setup_editable =function() {
                scope.editable = groovEditableConfig();
                angular.extend(scope.editable,scope.groovEditable);
                if(typeof scope.editable.elements[scope.prop] == "undefined") {
                    scope.editable.elements[scope.prop] = {type:'text',value:''};
                }
                if(typeof scope.editable.functions[scope.prop] == "undefined") {
                    scope.editable.functions[scope.prop] = function(){};
                }
                if(scope.editable.array) {
                    el.bind('dblclick',scope._prevent_and_add);
                    el.bind('contextmenu',scope._prevent_and_add);
                } else {
                    el.bind('dblclick',scope._prevent_and_edit);
                    el.bind('contextmenu', scope._prevent_and_edit);
                }
            }

            scope._init = function() {

                scope.is_transcluded = false;
                scope.single_editable_id = "editable-"+scope.identifier+"-"+scope.prop+"-1";
                scope.editing = -1;
                scope._focus_lost = false;
                scope._setup_editable();
                scope.function = scope.editable.functions[scope.prop];
                scope.input = scope.editable.elements[scope.prop];
                scope.editable_class = scope.editable.class+' input-text uneditable-input';
                scope.tag_class = 'tag-bubble false-tag-bubble tag-bubble-input span3 input-text';





                transclude(scope,function(clone){
                    scope.is_transcluded = clone.text().trim().length ? true: false;
                });
                scope.$watch('_focus_lost',function() {
                    if(scope._focus_lost) {
                        $timeout(function(){
                            if(scope._focus_lost) {
                                scope.save_node(true);
                            }
                        },500);
                    }
                });
                scope.$watch('editing',function() {
                    if(scope.editing != -1 && scope.editable.array) {
                        if(typeof scope.ngModel[scope.editing] == 'undefined') {
                            scope.editing = -1;
                        }
                    }
                })
                scope.$on(scope.identifier,scope.edit_node);
            }

            scope._init();
        }
    };
}]);
