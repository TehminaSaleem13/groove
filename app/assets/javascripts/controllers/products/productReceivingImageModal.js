groovepacks_controllers.
    controller('productReceivingImageModal', [ '$scope', 'product_id', 'product_data', '$state', '$stateParams', '$modalInstance', '$timeout','$modal','$q','groov_translator','products','warehouses','generalsettings','scanPack',
    function(scope, product_id, product_data, $state,$stateParams,$modalInstance,$timeout,$modal,$q,groov_translator,products,warehouses,generalsettings,scanPack) {
        var myscope = {};


        /**
         * Public methods
         */

        scope.ok = function() {
            scope.products.single.selected_image.added_to_receiving_instructions = true;
            products.single.update_image(scope.products.single.selected_image).then(function () {
                $modalInstance.close("ok-button-click");
            });
        };
        scope.cancel = function () {
            $modalInstance.dismiss("cancel-button-click");
        };

        scope.update_image_note = function (index) {
            products.single.update_image(scope.products.single.images[index]);
        };

        scope.select_unselect = function (image) {
            for (var i = 0; i < scope.products.single.images.length; i++) {
                if (scope.products.single.images[i].id != image.id) {
                    scope.products.single.images[i].checked = false;
                };
            };
            image.checked = !image.checked;
            scope.products.single.selected_image = image;
        };

        myscope.init = function() {
            scope.arrayEditableOptions = {
                array: true,
                selectable: true
            };
            scope.products = product_data;
            for (var i = 0; i < scope.products.single.images.length; i++) {
                scope.products.single.images[i].checked = false;
            };
            scope.products.single.selected_image = null;
        };
        myscope.init();

}]);
