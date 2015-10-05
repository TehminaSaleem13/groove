// groovepacks_admin_directives.directive('xsInputSync', function () {
//   return {
//     restrict: "A",
//     require: "?ngModel",
//     link: function (scope, element, attrs, ngModel) {
//       setInterval(function () {
//         if (!(element.val() == '' && ngModel.$pristine)) {
//           scope.$apply(function () {
//             ngModel.$setViewValue(element.val());
//           });
//         }
//         //console.log(scope);
//       }, 100);
//     }
//   };
// });
