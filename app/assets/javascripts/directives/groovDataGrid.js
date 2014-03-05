groovepacks_directives.directive('groovDataGrid', ['$timeout','$http','$sce','notification',function ($timeout,$http,$sce,notification) {
    var default_options = function() {
        return {
            identifier:'datagrid',
            select_all:false,
            show_hide:false,
            editable:false,
            sort_func:function() {},
            setup: {},
            all_fields:{}
        }
    }
    var default_field_options = function (){
        return {
            name: "field",
            sortable:true,
            class: "span2",
            hideable: true,
            hidden:false,
            transclude:'',
            grid_bind: ''
        }
    }
    return {
        restrict:"A",
        scope: {
            groovDataGrid: "=",
            rows: "=groovList"
        },
        templateUrl:"/assets/partials/datagrid.html",
        link: function(scope,el,attrs) {
            var myscope = {};
            scope.context_menu = function(event) {
                if(scope.options.show_hide) {
                    if(typeof myscope.contextmenu == "undefined") {
                        myscope.contextmenu = $("#"+scope.custom_identifier+"-context-menu .dropdown-menu");
                        myscope.contextmenu.on("mousedown",function(event){
                            event.stopPropagation();
                        });
                    }
                    scope.context_menu_shown = true;
                    myscope.contextmenu.css({
                        left:event.pageX,
                        top:event.pageY
                    });
                }
            }

            scope.show_hide = function(field) {
                field.hidden = ! field.hidden;
                scope.update();
            }

            scope.update = function() {
                var shown = []
                for(i in scope.options.all_fields) {
                    if(!scope.options.all_fields[i].hidden) {
                        shown.push(i);
                    }
                }
                $http.post('settings/save_columns_state.json',{identifier:scope.options.identifier,shown:shown, order:scope.theads}).success(function(data) {
                    if(data.status) {
                        notification.notify("Successfully saved column preferences",1);
                    } else {
                        notification.notify(data.messages,0);
                    }
                }).error(notification.server_error);
            }

            scope.compile = function(ind,field) {

                if(typeof scope.editable[field] == "undefined") {
                    scope.editable[field] = {};
                }
                if(typeof scope.editable[field][ind] == "undefined") {
                    scope.editable[field][ind] = $sce.trustAsHtml('<div groov-editable="options.editable" prop="{{field}}" ng-model="row" identifier="'+scope.options.identifier+'_list-'+field+'-'+ind+'">'+scope.options.all_fields[field].transclude+'</div>');
                }

                $timeout(function() {scope.$broadcast(scope.options.identifier+'_list-'+field+'-'+ind);},30);
            }
            myscope._init = function() {
                scope.theads = [];

                scope.editable={};
                var options = default_options();
                jQuery.extend(true,options,scope.groovDataGrid);
                for (i in scope.groovDataGrid.all_fields) {
                    options.all_fields[i] = default_field_options();
                    options.all_fields[i].editable = (scope.groovDataGrid.editable != false);
                    options.all_fields[i].draggable = (scope.groovDataGrid.draggable != false);
                    angular.extend(options.all_fields[i],scope.groovDataGrid.all_fields[i]);
                    if(options.all_fields[i].grid_bind !== '') {
                        options.all_fields[i].grid_bind = $sce.trustAsHtml(scope.groovDataGrid.all_fields[i].grid_bind);
                    }
                    scope.theads.push(i);
                }
                options.setup = scope.groovDataGrid.setup;
                scope.context_menu_shown = false;
                scope.options = options;
                scope.dragOptions = {
                    update: scope.update,
                    enabled: scope.options.draggable
                }
                scope.custom_identifier = scope.options.identifier + Math.floor(Math.random()*1000);


                $http.get('settings/get_columns_state.json?identifier='+scope.options.identifier).success(function(data) {
                    if(data.status) {
                        if(data.data) {

                            for(i in scope.options.all_fields) {
                                if(scope.options.all_fields[i].hideable) {
                                    scope.options.all_fields[i].hidden = true;
                                }
                            }

                            for(i in data.data.shown) {
                                if(typeof scope.options.all_fields[data.data.shown[i]] !=="undefined") {
                                    scope.options.all_fields[data.data.shown[i]].hidden = false;
                                }
                            }
                            scope.theads = data.data.order;
                        }
                    } else {
                        notification.notify(data.messages,0);
                    }

                }).error(notification.server_error);

            }

            myscope._init();
        }
    };
}]);
