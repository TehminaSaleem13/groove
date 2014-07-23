var subscription;

jQuery(function() {
  Stripe.setPublishableKey($('meta[name="stripe-key"]').attr('content'));
  return subscription.setupForm();
});

subscription = {
  setupForm: function() {
    return $('#subscription').submit(function(event) {
      event.preventDefault();
      console.log('processing card');
      $('input[type=submit]').attr('disabled', true);
      if ($('#number').length) {
        subscription.processCard();
        return false;
      } else {
        return true;
      }
    });
  },
  processCard: function() {
    var card;
    alert("processing")    
    card = {
      number: $('#number').val(),
      cvc: $('#cvc').val(),
      expMonth: $('#exp-month').val(),
      expYear: $('#exp-year').val()
    };
    return Stripe.createToken(card, subscription.handleStripeResponse);
  },
  handleStripeResponse: function(status, response) {
    if (status === 200) {
      $('#subscription_stripe_card_token').val(response.id);
      alert("entering ajax.");
      $.ajax({
        type: "PUT",
        contentType: "application/json",
        url: "/subscriptions/confirm_payment",
        data: JSON.stringify({ stripe_customer_token: response.id, id: $('#subscription_id').val() }),
        dataType: "json"
        
        }).error(function(response) {
          alert(response.getResponseHeader());
          alert('going to render the thankyou page.');
          window.location.href = 'https://local.groovepacker.com:3001/subscriptions/show/' + $('#subscription_id').val() + '?notice=Thankyou+for+subscribing%21';
        }).success(function(response){
          alert("success");
          alert(response.status);
        });
      alert("exiting ajax.");
    } else {
    alert('error');
      $('#stripe_error').text(response.error.message);
      return $('input[type=submit]').attr('disabled', false);
    }
  }
};
