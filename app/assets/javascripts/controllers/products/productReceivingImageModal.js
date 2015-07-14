groovepacks_controllers.
    controller('productReceivingImageModal', [ '$scope', 'product_id', 'product_data', '$state', '$stateParams', '$modalInstance', '$timeout','$modal','$q','groov_translator','products','warehouses','generalsettings','scanPack',
    function(scope, product_id, product_data, $state,$stateParams,$modalInstance,$timeout,$modal,$q,groov_translator,products,warehouses,generalsettings,scanPack) {
        var myscope = {};


        /**
         * Public methods
         */

        scope.ok = function() {
            products.single.update_image(scope.products.single.selected_image,true).then(function () {
                $modalInstance.close("ok-button-click");
            });
        };
        scope.cancel = function () {
            $modalInstance.dismiss("cancel-button-click");
        };

        scope.select_unselect = function (image) {
            for (var i = 0; i < scope.products.single.images.length; i++) {
                if (scope.products.single.images[i].id != image.id) {
                    scope.products.single.images[i].checked = false;
                };
            };
            image.checked = !image.checked;
            scope.products.single.selected_image = image;
        }

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
