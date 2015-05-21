groovepacks_admin_services.factory("groov_audio", ['$timeout',function($timeout) {
    var load = function(url,volume) {
        var audio = new Audio();
        audio.addEventListener('loadstart', function(e) {
            audio.volume = volume;
        });
        $timeout(function() {
            audio.src= url;
        },1);
        return audio;
    };
    var play = function(audio) {
        if(typeof audio =='object' && typeof audio['play'] =='function') {
            audio.play();
        }
    };
    return {
        load: load,
        play:play
    };

}]);
