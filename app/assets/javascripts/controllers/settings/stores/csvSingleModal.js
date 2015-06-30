groovepacks_controllers.controller('csvSingleModal', [ '$scope', 'store_data', '$state', '$stateParams','$modal',
         '$modalInstance', '$timeout', 'hotkeys', 'stores','warehouses','notification','$q',
function(scope, store_data, $state, $stateParams, $modal, $modalInstance, $timeout, hotkeys, stores, warehouses, notification, $q) {
     var myscope = {};

     /**
      * Public methods
      */

    scope.ok = function() {
        var result = $q.defer();
        for(var i = 0; i < scope.csv.importer[scope.csv.importer.type]['map_options'].length; i++) {
            if (scope.csv.importer[scope.csv.importer.type]['map_options'][i].name == "Order Date/Time") {
                if (scope.csv.importer[scope.csv.importer.type]['map_options'][i].disabled) {
                    scope.csv.current.order_placed_at = null;
                    myscope.ok_import();
                    break;
                } else {
                    if (confirm("An Order Date/Time has not been mapped. Would you like to continue using the current Date/Time for each imported order?")) {
                        scope.csv.current.order_placed_at = new Date();
                        myscope.ok_import();
                        result.resolve();
                        break;
                    } else {result.resolve();};
                };
            } else {continue;};
        }
        return result.promise;
    };

    myscope.ok_import = function() {
        stores.csv.do_import(scope.csv).success(function(data) {
            if(data.status) {
                $modalInstance.close("ok-button-click");
            } else {
                scope.parse();
            }
        });
    };

    scope.cancel = function () {
        $modalInstance.dismiss("cancel-button-click");
    };
    scope.parse = function() {
        if (scope.csv.importer[scope.csv.importer.type] != null) {
            $timeout(myscope.doparse);
        }
    };

    scope.column_map = function(col,option) {
        var map_overwrite = true;
        for(var prop in scope.csv.current.map) {
            if(scope.csv.current.map.hasOwnProperty(prop) && scope.csv.current.map[prop].value === option.value) {
                if(confirm("Are you sure you want to change the mapping for "+option.name+" to current column?")) {
                    scope.column_unmap(prop);
                } else {
                    map_overwrite = false;
                }
                break;
            }
        }

        if(map_overwrite) {
            scope.csv.current.map[col] = {};
            scope.csv.current.map[col].name = option.name;
            scope.csv.current.map[col].value = option.value;
            option.disabled = true;
        }
    };


    scope.column_unmap = function(col) {
        myscope.disable(scope.csv.current.map[col].value,false);
        scope.csv.current.map[col].name = scope.csv.importer.default_map.name;
        scope.csv.current.map[col].value = scope.csv.importer.default_map.value;
    };


    myscope.disable = function(value,disable) {
        for(var i = 0; i < scope.csv.importer[scope.csv.importer.type]['map_options'].length; i++) {
            if(scope.csv.importer[scope.csv.importer.type]['map_options'][i].value == value) {
                scope.csv.importer[scope.csv.importer.type]['map_options'][i].disabled = disable;
            }
        }
    };

    myscope.doparse = function() {
        scope.csv.current.data = [];
        scope.csv.current.head = [];
        scope.empty_cols = [];
        var in_entry = false;
        var secondary_split = [];
        var initial_split = scope.csv.importer[scope.csv.importer.type]["data"].split(/\r?\n/g);
        var tmp_record = '';
        var row_array = [];
        var separator = scope.csv.current.sep;
        if(separator == '') {
            separator = " ";
        }
        var final_record = [];
        var maxcolumns = 0;
        for(var i = 0; i < initial_split.length; i++) {
            if(scope.csv.current.fix_width == 1) {
                row_array = initial_split[i].chunk(scope.csv.current.fixed_width);
                if(maxcolumns < row_array.length) {
                    maxcolumns = row_array.length;
                }
                final_record.push(row_array);
                row_array = [];
            } else {
                secondary_split = initial_split[i].split(separator);
                for(var j =0; j < secondary_split.length; j++) {
                    if(secondary_split[j].charAt(0) == scope.csv.current.delimiter && secondary_split[j].charAt(secondary_split[j].length -1) != scope.csv.current.delimiter) {
                        in_entry = true;
                    } else if(secondary_split[j].charAt(secondary_split[j].length -1) == scope.csv.current.delimiter) {
                        in_entry = false;
                    }

                    if(in_entry) {
                        if( j == secondary_split.length -1) {
                            tmp_record += secondary_split[j];
                        } else {
                            tmp_record += secondary_split[j]+separator;
                        }
                    } else {
                        row_array.push((tmp_record + secondary_split[j]).trimmer(scope.csv.current.delimiter));
                        if( j == secondary_split.length -1) {
                            tmp_record = "";
                        } else {
                            tmp_record = scope.csv.current.delimiter;
                        }
                    }
                }
                if(in_entry) {
                    tmp_record += "\r\n";

                } else {
                    if(maxcolumns < row_array.length) {
                        maxcolumns = row_array.length;
                    }
                    final_record.push(row_array);
                    row_array = [];
                }
            }
        }
        for(i = 0; i< maxcolumns; i++) {
            scope.empty_cols.push(i);

            if((i in scope.csv.current.map &&
                'name' in scope.csv.current.map[i] &&
                'value' in scope.csv.current.map[i])) {
                if(scope.csv.current.map[i].value !== scope.csv.importer.default_map.value) {
                    myscope.disable(scope.csv.current.map[i].value,true);
                }
            } else {
                scope.csv.current.map[i] = scope.csv.importer.default_map;
            }
        }
        scope.csv.current.head = final_record.slice(0,1)
        scope.csv.current.data = final_record.slice(scope.csv.current.rows-1);

        scope.csv.current.data.pop(1);
        final_record = [];
        row_array = [];
        $timeout(function(){
        $('#csv_table_top_scroll').css("width",$('#map_table').width());
        }, 1000);
        
    };

     myscope.init = function() {
         scope.csv = {};
         scope.stores = store_data;
         stores.csv.import(scope.stores, scope.stores.single.id).success(function(data) {
             scope.csv.importer = {};
             scope.csv.importer.default_map = {value:'none', name:"Unmapped"};
             if("product" in data && "data" in data["product"]) {
                 scope.csv.importer.product = data["product"];
                 scope.csv.importer.type = "product";
             }
             if("order" in data && "data" in data["order"]) {
                 scope.csv.importer.order = data["order"];
                 scope.csv.importer.type = "order";
             }
             scope.csv.current = scope.csv.importer[scope.csv.importer.type]["settings"].map;
             scope.csv.current.store_id = data["store_id"];
             scope.csv.current.type = scope.csv.importer.type;
             scope.csv.current.name = scope.csv.importer[scope.csv.importer.type]["settings"].name;
             angular.forEach(scope.csv.importer[scope.csv.importer.type]["map_options"],function(opt) {
                opt.disabled = false;
             });

             scope.parse();
         });
     };

    myscope.init();
}]);
