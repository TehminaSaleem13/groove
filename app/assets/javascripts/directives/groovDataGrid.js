groovepacks_directives.directive('groovDataGrid', ['$timeout','$http','$sce','notification',function ($timeout,$http,$sce,notification) {
    var default_options = function() {
        return {
            identifier:'datagrid',
            select_all:false,
            selectable:false,
            show_hide:false,
            editable:false,
            sortable:false,
            sort_func:function() {},
            setup: {},
            all_fields:{}
        }
    };
    var default_field_options = function (){
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
        restrict:"A",
        scope: {
            groovDataGrid: "=",
            rows: "=groovList"
        },
        templateUrl:"/assets/views/directives/datagrid.html",
        link: function(scope,el,attrs) {
            var myscope = {};
            scope.context_menu = function(event) {
                if(scope.options.show_hide) {
                    scope.context_menu.shown = !scope.context_menu.shown;
                    if(typeof event != "undefined") {
                        event.preventDefault();
                        event.stopPropagation();
                        var offset = el.offset();
                        scope.context_menu_style = {left: event.pageX - offset.left, top: event.pageY - offset.top }
                    }
                }
            };

            scope.show_hide = function(field) {
                field.hidden = ! field.hidden;
                scope.update();
            };

            scope.check_uncheck = function(row) {
                if(scope.options.selectable) {
                    row.checked = !row.checked;
                }
            };

            scope.update = function() {
                var shown = [];
                var hidden = [];
                for(var i in scope.options.all_fields) {
                    if(scope.options.all_fields.hasOwnProperty(i)) {
                        if(!scope.options.all_fields[i].hidden) {
                            shown.push(i);
                        } else {
                            hidden.push(i);
                        }
                    }
                }

                myscope.headOrder = shown.concat(hidden);
                scope.theads = shown;

                $http.post('settings/save_columns_state.json',{identifier:scope.options.identifier,shown:shown, order:myscope.headOrder}).success(function(data) {
                    if(data.status) {
                        notification.notify("Successfully saved column preferences",1);
                    } else {
                        notification.notify(data.messages,0);
                    }
                }).error(notification.server_error);
            };

            scope.compile = function(ind,field) {

                if(typeof scope.editable[field] == "undefined") {
                    scope.editable[field] = {};
                }
                if(typeof scope.editable[field][ind] == "undefined") {
                    scope.editable[field][ind] = $sce.trustAsHtml('<div groov-editable="options.editable" prop="{{field}}" ng-model="'+scope.options.all_fields[field].model+'" identifier="'+scope.options.identifier+'_list-'+field+'-'+ind+'">'+scope.options.all_fields[field].transclude+'</div>');
                }

                $timeout(function() {scope.$broadcast(scope.options.identifier+'_list-'+field+'-'+ind);},30);
            };
            myscope._init = function() {
                myscope.headOrder = [];
                scope.theads = [];

                scope.editable={};
                var options = default_options();
                jQuery.extend(true,options,scope.groovDataGrid);
                for (var i in scope.groovDataGrid.all_fields) {
                    if(scope.groovDataGrid.all_fields.hasOwnProperty(i)){
                        options.all_fields[i] = default_field_options();
                        options.all_fields[i].editable = (options.editable != false);
                        options.all_fields[i].draggable = (options.draggable != false);
                        options.all_fields[i].sortable = (options.sortable != false);
                        angular.extend(options.all_fields[i],scope.groovDataGrid.all_fields[i]);
                        if(options.all_fields[i].transclude !== '') {
                            options.all_fields[i].transclude = $sce.trustAsHtml(scope.groovDataGrid.all_fields[i].transclude);
                        }
                        myscope.headOrder.push(i);
                        scope.theads.push(i);
                    }
                }
                options.setup = scope.groovDataGrid.setup;
                scope.context_menu_shown = false;
                scope.context_menu_style = {};
                scope.options = options;
                scope.dragOptions = {
                    update: scope.update,
                    enabled: scope.options.draggable
                };
                scope.custom_identifier = scope.options.identifier + Math.floor(Math.random()*1000);


                $http.get('settings/get_columns_state.json?identifier='+scope.options.identifier).success(function(data) {
                    if(data.status) {
                        if(data.data) {

                            for(var i in scope.options.all_fields) {
                                if(scope.options.all_fields.hasOwnProperty(i)) {
                                    if(scope.options.all_fields[i].hideable) {
                                        scope.options.all_fields[i].hidden = true;
                                    }
                                }
                            }

                            for(var j in data.data.shown) {
                                if(data.data.shown.hasOwnProperty(j) &&
                                   typeof scope.options.all_fields[data.data.shown[j]] !=="undefined") {
                                    scope.options.all_fields[data.data.shown[j]].hidden = false;
                                }
                            }
                            scope.theads = data.data.shown;
                            myscope.headOrder = data.data.order;
                        }
                    } else {
                        notification.notify(data.messages,0);
                    }

                }).error(notification.server_error);

            };

            myscope._init();
        }
    };
}]);
