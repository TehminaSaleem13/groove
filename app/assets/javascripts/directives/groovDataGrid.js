groovepacks_directives.directive('groovDataGrid', ['$timeout','$http','notification',function ($timeout,$http,notification) {
    return {
        restrict:"A",
        scope: {
            options: "=groovDataGrid"
        },
        link: function(scope,el,attrs) {
            var myscope = {};
            myscope._persist_state = function() {
                myscope.columns = {};
                myscope.set_columns();

                $http.post('settings/save_columns_state.json',{identifier:scope.options.identifier,shown:myscope.shown_fields, order:myscope.columns}).success(function(data) {
                    if(data.status) {
                        notification.notify("Successfully saved column preferences",1);
                    } else {
                        notification.notify(data.messages,0);
                    }
                }).error(notification.server_error);
            }
            myscope.set_columns = function() {
                el.find('th').each(function(index){myscope.columns[this.getAttribute('data-header')] = index;});
            }
            myscope._checkSwapNodes = function() {
                myscope.set_columns();
                scope.$apply(
                    function() {
                        el.find('tr').each(
                            function(index){
                                var children = this.children;
                                for (i=0; i <children.length; i++) {
                                    if( myscope.columns[children[i].getAttribute('data-header')] != i) {
                                        myscope._doRealSwap(children[i],children[myscope.columns[children[i].getAttribute('data-header')]]);
                                    }
                                }
                            }
                        );
                        $timeout(myscope._showHideField);
                    }
                );
            }

            myscope._doRealSwap = function swapNodes(a, b) {
                var aparent = a.parentNode;
                var asibling = a.nextSibling === b ? a : a.nextSibling;
                b.parentNode.insertBefore(a, b);
                aparent.insertBefore(b, asibling);
            }

            myscope._showHideField = function(key,options) {
                scope.$apply(function() {
                    $(".context-menu-item i").removeClass("icon-ok").addClass("icon-remove");
                    $("#"+myscope.custom_identifier+" th, #"+myscope.custom_identifier+" td").hide();
                    if(typeof key !== "undefined") {
                        var array_position = myscope.shown_fields.indexOf(key);
                        if(array_position > -1) {
                            myscope.shown_fields.splice( array_position, 1 );
                        } else {
                            myscope.shown_fields.push(key);
                        }
                        myscope._persist_state();
                    }
                    for (i in myscope.shown_fields) {
                        $(".rt_field_"+myscope.shown_fields[i]+" i").removeClass("icon-remove").addClass("icon-ok");
                        $("[data-header='"+myscope.shown_fields[i]+"']").show();
                    }
                });
                return false;
            }
            myscope._init = function() {
                myscope.all_fields = {};
                myscope.shown_fields = [];
                myscope.custom_identifier = scope.options.identifier + Math.floor(Math.random()*1000);
                myscope.columns = {};
                myscope.shown_fields = scope.options.shown_fields;
                el.attr('id', myscope.custom_identifier);
                for(i in scope.options.all_fields) {
                    myscope.all_fields[i] = {name:"<i class='icon icon-ok'></i> "+ scope.options.all_fields[i], className:"rt_field_"+i};
                }

                $http.get('settings/get_columns_state.json?identifier='+scope.options.identifier).success(function(data) {
                    if(data.status) {
                        if(data.data) {
                            myscope.shown_fields = data.data.shown;
                            myscope.columns = data.data.order;
                        } else {
                            myscope.set_columns();
                        }
                    } else {
                        notification.notify(data.messages,0);
                    }

                }).error(notification.server_error);


                //Register events and make function calls
                $.contextMenu({
                    // define which elements trigger this menu
                    selector: '#'+myscope.custom_identifier+' thead',
                    // define the elements of the menu
                    items: myscope.all_fields,
                    // there's more, have a look at the demos and docs...
                    callback: myscope._showHideField
                });
                $('#'+myscope.custom_identifier).dragtable({dragaccept:'.dragtable-sortable',clickDelay:250,persistState: myscope._persist_state});
                scope.$on("groov-data-grid-trigger",function() {
                    $timeout(myscope._checkSwapNodes,10);
                });
            }

            myscope._init();
        }
    };
}]);
