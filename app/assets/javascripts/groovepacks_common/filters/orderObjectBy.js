groovepacks_filters.filter('orderObjectBy', function() {
  return function(items, field, reverse, func, func_params) {

    var filtered = [];

    angular.forEach(items, function(item) {
      filtered.push(item);
    });

    filtered.sort(function (a, b) {
      return (
        a[field] > b[field]) ? 1 :
        ((a[field] < b[field]) ? -1 : 0
      );
    });

    if(func){
      filtered = func(filtered, func_params);
    }

    if(reverse) filtered.reverse();
    return filtered;
  };
});
