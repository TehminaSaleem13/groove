Subscription = {

  validate: function() {
    return (
      this.validate_email() &
      this.validate_tenant_name() &
      this.validate_username() &
      this.validate_password() &
      this.validate_password_confirmation() &
      this.validate_tos()
    )
  },

  validate_email : function() {
    var email = $('#email').val();
    var atpos = email.indexOf("@");
    var dotpos = email.lastIndexOf(".");
    var valid = false;
    if (email == null || email == "") {
      valid = false;
      if (valid.tenant_name) {
        $('#error-email-block').html("email must be filled out");
      }
    }
    else if (atpos < 1 || dotpos < atpos + 2 || dotpos + 2 >= email.length) {
      valid = false;
      $('#error-email-block').html("email is not valid");
    } else {
      $.ajax({
          type: "GET",
          contentType: "application/json; charset=utf-8",
          url: "/subscriptions/valid_email",
          data: {email: $('#email').val()},
          dataType: "json",
          async: false

      }).error(function (response) {

      }).success(function (response) {
          if (!response.valid) {
              $('#error-email-block').html($('#email').val() + " email already exists");
              valid = false;
              //$('#email').focus();
          }
          else {
              $('#error-email-block').html("");
              valid = true;
              //user_name.focus();
          }
      });
    }

    return valid;
  },

  validate_tenant_name : function() {
    var tenant_name = $("#tenant_name").val();
    tenant_name = tenant_name.toLowerCase();
    var valid = false;
    $("#tenant_name").val(tenant_name);
    if (tenant_name == null || tenant_name == "" || tenant_name.length < 4) {
        valid = false;
        $('#error-tenant-block').html("Site name must be at least 4 characters long");
        //this.focus();
    }
    else {
      $.ajax({
        type: "GET",
        contentType: "application/json; charset=utf-8",
        url: "/subscriptions/valid_tenant_name",
        data: {tenant_name: $('#tenant_name').val()},
        dataType: "json",
        async: false
      }).error(function (response) {

      }).success(function (response) {
        if (!response.valid) {
          $('#error-tenant-block').html(response.message);
          valid = false;
          //$('#tenant_name').focus();
        } else {
          $('#error-tenant-block').html("");
          valid = true;
          //email.focus();
        }
      });
    }
    return(valid);
  },

  validate_username : function() {
    var user_name = $('#user_name').val();
    var valid = false;

    if (user_name == null || user_name == "") {
      valid = false;
      $('#error-username-block').html("username must be filled out");
    } else {
      $('#error-username-block').html("");
      valid = true;
    }

    return (valid);
  },

  validate_password : function() {
    var password = $('#password').val();
    var valid = false;
    if (password == null || password == "") {
      valid = false;
      if (valid.user_name) {
        $('#error-password-block').html("password must be filled out");
        $('#error-password-conf-block').html("");
      }
    } else if (password.length < 6) {
      valid = false;
      if (valid.user_name) {
          $('#error-password-block').html("Password should be at least 6 characters");
          $('#error-password-conf-block').html("");
      }
    } else {
      valid = true;
      $('#error-password-block').html("");
      $('#error-password-conf-block, #error-password-block').html("");
    }
    return(valid);
  },

  validate_password_confirmation : function() {
    var password_conf = $('#password_conf').val();
    var valid = false;
    if (password_conf == null || password_conf == "" || password_conf != password.value) {
      valid = false;
      $('#error-password-conf-block, #error-password-block').html("password and password confirmation must match");
    }
    else {
      valid = true;
      $('#error-password-conf-block, #error-password-block').html("");
    }
    return (valid);
  },

  validate_tos : function() {
    var tos = $('#tos_checkbox').is(':checked');
    var valid = false;
    if (tos == null || tos == "" || tos == false) {
        valid = false;
        $('#error-tos-block').html("Please click I agree for TOS and Privacy Policy");
    } else {
        valid = true;
        $('#error-tos-block').html("");
    }
    return (valid);
  }
}