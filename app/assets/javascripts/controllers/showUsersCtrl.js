groovepacks_controllers.
controller('showUsersCtrl', [ '$scope', '$http', '$timeout', '$routeParams', '$location', '$route', '$cookies',
    function( $scope, $http, $timeout, $routeParams, $location, $route, $cookies) {
    	$http.get('/home/userinfo.json').success(function(data){
    		$scope.username = data.username;
    	});
        $('.modal-backdrop').remove();
        $scope.current_page="show_users";
        $scope.currently_open = 0;
    	$http.get('/user_settings/userslist.json').success(function(data) {
    		$scope.users = data;
    		$scope.reverse = false;
            $scope.newUser = {};
    	}).error(function(data) {
    		$scope.notify("There was a problem retrieving users list",0);
    	});

        $scope.show_password = true;
    	$scope.submit = function(newUser) {

    		console.log($scope.newUser);
    		$http.post('/user_settings/createUser.json', this.newUser).success(function(data) {
    			console.log(data);
    			if(!data.result)
    			{
    				$scope.notify(data.messages,0);
    			}
    			else
    			{
    				$scope.newUser = {};
    				$('#createUser').modal('hide');

    				$http.get('/user_settings/userslist.json').success(function(data) {
						    		var usersScope = angular.element($("#userstbl")).scope();
								      usersScope.users = data;
								      if(!$scope.$$phase) {
								        usersScope.$apply();
								      }
						    	}).error(function(data) {
						    		$scope.notify("There was a problem retrieving users list.",0);
						    	});
                    $scope.edit_status = false;
                    $scope.show_password = true;
    			}
    		})
    	}
        $scope.change_password = function() {
            $scope.show_password = true;
        }
    	$scope.handlesort = function(predicate) {
    		$scope.predicate = predicate;
    		if ($scope.reverse == false)
    		{
    			$scope.reverse = true;
    		}
    		else
    		{
    			$scope.reverse = false;
    		}

    	}

        $scope.handle_change_status = function(event) {

            userArray = [];

            /* get user objects of checked items */
            for( var user_index=0; user_index<= $scope.users.length-1; user_index++)
            {
                if ($scope.users[user_index].checked == 1)
                {
                    var user = new Object();
                    user.id = $scope.users[user_index].id;
                    user.index = user_index;
                    if(event=='active')
                    {
                        user.active = 1;
                    }
                    else
                    {
                        user.active = 0;
                    }
                    userArray.push(user);
                }
            }
            console.log(userArray);
            /* update the server with the changed status */
            $http.put('/user_settings/changeuserstatus.json', userArray).success(function(data){
                if (data.status)
                {
                    for(i=0; i<= userArray.length -1; i++)
                    {
                        $scope.users[userArray[i].index].active = userArray[i].active;
                        $scope.users[userArray[i].index].checked = false;
                    }
                    $scope.notify("Status updated successfully",1);
                }
                else
                {
                    $scope.notify("There was a problem changing users status",0);
                }
                }).error(function(data){
                    $scope.notify("There was a problem changing users status",0);
                });
        }

        $scope.handle_user_delete_event = function(event) {

            userArray = [];
            /* get user objects of checked items */
            for( var user_index=0; user_index<= $scope.users.length-1; user_index++)
            {
                if ($scope.users[user_index].checked == 1)
                {
                    var user = new Object();
                    user.id = $scope.users[user_index].id;
                    user.index = user_index;
                    if(event=='active')
                    {
                        user.active = 1;
                    }
                    else
                    {
                        user.active = 0;
                    }
                    userArray.push(user);
                }
            }
            console.log(userArray);
            /* update the server with the changed status */
            $http.put('/user_settings/deleteuser.json', userArray).success(function(data){
                        if (data.status)
                        {
                            $scope.notify("Deleted successfully",1);
                            $http.get('/user_settings/userslist.json').success(function(data) {
                                $scope.users = data;
                                $scope.reverse = false;
                            }).error(function(data) {
                                $scope.notify("There was a problem retrieving users list",0);
                            });
                        }
                        else
                        {
                            $scope.notify("There was a problem deleting users",0);
                        }
                        }).error(function(data){
                            $scope.notify("There was a problem changing users status",0);
                        });
        }

        $scope.handle_user_duplicate_event = function(event) {

            userArray = [];
            /* get user objects of checked items */
            for( var user_index=0; user_index<= $scope.users.length-1; user_index++)
            {
                if ($scope.users[user_index].checked)
                {
                    var user = new Object();
                    user.id = $scope.users[user_index].id;
                    user.index = user_index;
                    if(event=='active')
                    {
                        user.active = 1;
                    }
                    else
                    {
                        user.active = 0;
                    }
                    userArray.push(user);
                }
            }
            console.log(userArray);
            /* update the server with the changed status */
            $http.put('/user_settings/duplicateuser.json', userArray).success(function(data){
                        if (data.status)
                        {
                            $scope.notify("Duplicated successfully",1);
                            $http.get('/user_settings/userslist.json').success(function(data) {
                                $scope.users = data;
                                $scope.reverse = false;
                            }).error(function(data) {
                                $scope.notify("There was a problem retrieving users list",0);
                            });
                        }
                        else
                        {
                            $scope.notify("There was a problem duplicating users",0);
                        }
                        }).error(function(data){
                            $scope.notify("There was a problem duplicating users",0);
                        });
        }

    $scope.getuserinfo = function(id,index) {
        if(typeof index !== 'undefined'){
            $scope.currently_open = index;
        }
        /* update the server with the changed status */
        $http.get('/user_settings/getuserinfo.json?id='+id).success(function(data){
            if (data.status)
            {
                $scope.newUser = data.user;
                $scope.newUser.other1 = data.user.other;
                $scope.newUser.createEdit_packer = data.user.createEdit_from_packer;
                $scope.edit_status = true;
                $scope.show_password = false;
                $('#createUser').modal('show');
            }
            else
            {
                $scope.notify("There was a problem getting user information",0);
            }
        }).error(function(data){
            $scope.notify("There was a problem getting user information",0);
        });
    }

    $scope.select_deselectall_event = function() {
        /* get user objects of checked items */
        for( var user_index=0; user_index<= $scope.users.length-1; user_index++)
        {
            $scope.users[user_index].checked = $scope.select_deselectall;
            //console.log($scope.select_deselectall);
        }
    }

    $scope.create_user = function() {
        $scope.edit_status = false;
        $scope.show_password = true;
        $scope.newUser = {};
        $scope.newUser.active = true;
        $('#createUser').modal('show');
    }

    $scope.keyboard_nav_event = function(event) {
        if($('#createUser').hasClass("in") &&  $scope.edit_status) {
            if(event.which == 38) {//up key
                if($scope.currently_open > 0) {
                    $scope.getuserinfo($scope.users[$scope.currently_open -1].id, $scope.currently_open - 1);
                } else {
                    alert("Already at the top of the list");
                }
            } else if(event.which == 40) { //down key
                if($scope.currently_open < $scope.users.length - 1) {
                    $scope.getuserinfo($scope.users[$scope.currently_open + 1].id, $scope.currently_open + 1);
                } else {
                    alert("Already at the bottom of the list");
                }
            } else if(event.which == 39 || event.which == 37) {
                //Horizontal movement
                var mytab = $("#myTab li");
                var count = mytab.length;
                var active_index = $("#myTab li.active").index();
                var next_index = 1;
                var prev_index = count;

                if(event.which == 39) { //right key
                    if(active_index+1 < count) {
                        next_index = active_index+2;
                    }
                    $("#myTab li:nth-child("+next_index+") a").click();
                } else if(event.which == 37) { //left key

                    if(active_index > 0) {
                        prev_index = active_index;
                    }
                    $("#myTab li:nth-child("+prev_index+") a").click();
                }
            }

        }
    }
    $('#createUser').keydown($scope.keyboard_nav_event);
    $("#user-search-query").focus();
}]);
