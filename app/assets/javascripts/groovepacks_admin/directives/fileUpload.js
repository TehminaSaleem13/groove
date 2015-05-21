groovepacks_admin_directives.directive('fileUpload', function () {
    return {
        scope: true,
        link: function (scope, el, attrs) {
            el.bind('change', function (event) {
                var file = event.target.files[0];
                scope.$emit("fileSelected", { name: attrs.name, file: file });
            });
        }
    };
});
