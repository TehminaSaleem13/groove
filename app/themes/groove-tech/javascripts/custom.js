$(document).ready(function(){
	$(".no_of_users").val(3);
	add_discount_if_billing_annually();
	$(".no_of_users_inc").click(function(){
		calculate("+");
	});
	$(".no_of_users_dec").click(function(){
		calculate("-");
	});

	$(".bill_annually").change(function(){
		add_discount_if_billing_annually();
	});

	function calculate(sign){
		var no_of_users = $('.no_of_users').val();
		var total_amount;
		no_of_users = parseFloat(no_of_users);
		if(sign=="+") {
			no_of_users = no_of_users+1;
		} else {
			if(no_of_users>2) {
				no_of_users = no_of_users-1;
			}
		}
		$(".price_label").text(50*no_of_users);
		$(".discount_amount").text(5*no_of_users);
		$(".no_of_users_label").text(no_of_users);
		$(".no_of_users").val(no_of_users);
		add_discount_if_billing_annually();
	}

	function add_discount_if_billing_annually() {
		var no_of_users = $('.no_of_users').val();
		no_of_users = parseFloat(no_of_users);
		var checked = $(".bill_annually:checked").length;
		var total_amount;
		if(checked>0) {
			$('.discount_section').removeClass("fade4");
			total_amount = (50*no_of_users)-(5*no_of_users);
		} else {
			$('.discount_section').addClass("fade4");
			total_amount = 50*no_of_users;
		}
		$(".total_amount").text(total_amount);
	}
	
});

/* Cost calculator start*/
  $(document).ready(function () {
    $("#email_text").text($("#email_text").val())
    $("#total_expedited, #total_international, #cancel_order_shipment, #lifetime_order_val, #negative_post_review, #inventory_shortage, #lifetime_value, #avg_current_order_val").css("background", "#dedbdb");
    $(document).on('change paste keyup input', function () {
      var order_count = $("#order_count").val();
      var packer_count = $("#packer_count").val();
      var avg_error = $("#avg_error").val();
      if (order_count != null && packer_count != null && avg_error != null){
        $("#error_per_day").html(parseFloat(order_count*packer_count*(avg_error/100)).toFixed(2));
        $("#error_per_day").val(parseFloat(order_count*packer_count*(avg_error/100)).toFixed(2));
      var error_per_day = $("#error_per_day").val();
      var total_cost_per_error = $("#total_cost_per_error").val();
      $("#daily_cost_error").html(parseFloat(total_cost_per_error*error_per_day));
      $("#daily_cost_error").val(parseFloat(total_cost_per_error*error_per_day));
      };
      $("#cost_of_plan").val(packer_count*50)
      $("#cost_of_plan").html(packer_count*50);
    });

    
    $(document).on('change paste keyup input', function(){ 
      var regular_percentage = parseFloat($("#regular_percentage").val());
      var avg_comm = parseFloat($("#avg_comm").val());
      var regular_percentage = parseFloat($("#regular_percentage").val());
      var regular_comm = parseFloat($("#regular_comm").val());
      var escalated_comm = parseFloat($("#escalated_comm").val());
      if(regular_percentage != null){
        $("#regular_percentage").on('change paste keyup input', function(){
          $("#escalated_percentage").html(parseFloat(100-regular_percentage).toFixed(2));
          $("#escalated_percentage").val(parseFloat(100-regular_percentage).toFixed(2));
        });
      };
      if(regular_percentage != null && avg_comm != null && regular_comm != null && regular_percentage != null && escalated_comm != null) {
        $("#cost_of_comm").html(parseFloat(avg_comm*(((regular_comm*regular_percentage)/100)+((escalated_comm*(100-regular_percentage))/100))).toFixed(2));
         $("#cost_of_comm").val(parseFloat(avg_comm*(((regular_comm*regular_percentage)/100)+((escalated_comm*(100-regular_percentage))/100))).toFixed(2))
      };
    });

    // $('#return_shipping_cost, #return_shipping_insurance, #cost_recieving_process, #cost_confirm, #return_shipping_percentage').on('change paste keyup input', function(){
    //   var return_shipping_cost = parseFloat($("#return_shipping_cost").val());
    //   var return_shipping_insurance = parseFloat($("#return_shipping_insurance").val());
    //   var cost_recieving_process = parseFloat($("#cost_recieving_process").val());
    //   var cost_confirm = parseFloat($("#cost_confirm").val());
    //   var return_shipping_percentage = parseFloat($("#return_shipping_percentage").val());
    //   if(return_shipping_cost != null && return_shipping_insurance != null && cost_recieving_process != null && cost_confirm != null && return_shipping_percentage != null ){
    //     $("#return_ship").html(parseFloat((return_shipping_percentage/100)*(return_shipping_cost + return_shipping_insurance + cost_recieving_process + cost_confirm)));
    //     $("#return_ship").val(parseFloat((return_shipping_percentage/100)*(return_shipping_cost + return_shipping_insurance + cost_recieving_process + cost_confirm)))
    //   }
    // });

    $("#return_shipping_percentage").on('change paste keyup input', function(){
      var return_shipping_percentage = $("#return_shipping_percentage").val();
      if(return_shipping_percentage != null){
        $("#product_abandonment_percentage").html(parseFloat(100 - return_shipping_percentage));
        $("#product_abandonment_percentage").val(parseFloat(100 - return_shipping_percentage));
      };
    });

    $("#product_abandonment_percentage").on('change paste keyup input', function(){
      var product_abandonment_percentage = $("#product_abandonment_percentage").val();
      if(product_abandonment_percentage != null){
        $("#return_shipping_percentage").html(parseFloat(100 - product_abandonment_percentage));
        $("#return_shipping_percentage").val(parseFloat(100 - product_abandonment_percentage));
      };
    });

    $(document).on('change paste keyup input', function(){
      var return_shipping_percentage = $("#return_shipping_percentage").val();
      var avg_product_abandonment = $("#avg_product_abandonment").val();
      if(return_shipping_percentage != null && avg_product_abandonment != null){
        $("#product_abandonment").html(parseFloat((100-return_shipping_percentage)*avg_product_abandonment/100).toFixed(2))
        $("#product_abandonment").val(parseFloat((100-return_shipping_percentage)*avg_product_abandonment/100).toFixed(2))
      };
    });

    $(document).on('change paste keyup input', function() {
      var incorrect_item = $("#incorrect_item").val();
      var avg_order_profit = $("#avg_order_profit").val();
      var incorrect_item_per = parseFloat(100/incorrect_item)
      $("#incorrect_percentage").html(incorrect_item_per);
      if(incorrect_item != null && avg_order_profit != null){
        canc = parseFloat(avg_order_profit/incorrect_item);
        $("#calc_cost").html(canc);
        $("#calc_cost").val(canc);
      };
    });

    $(document).on('change paste keyup input', function() {
      var frustration_order = $("#frustration_order").val();
      var avg_customer_value = $("#avg_customer_value").val();
      var incorrect_item_per = parseFloat(100/frustration_order)
      $("#frustration_percentage").html(incorrect_item_per);
      if(frustration_order != null && avg_customer_value != null){
        canc = parseFloat(avg_customer_value/frustration_order).toFixed(2);
        $("#future_calc_cost").html(canc);
        $("#future_calc_cost").val(canc);
      };
    });

    $(document).on('change paste keyup input', function() {
      var social_error = $("#social_error").val();
      var future_customer_value = $("#future_customer_value").val();
      var incorrect_item_per = parseFloat(100/social_error)
      $("#social_error_percentage").html(incorrect_item_per);
      if(social_error != null && future_customer_value != null){
        canc = parseFloat(future_customer_value/social_error).toFixed(2);
        $("#life_long_calc_cost").html(canc);
        $("#life_long_calc_cost").val(canc);
      };
    });

    $(document).on('change paste keyup input', function(){
      var cost_apology = parseFloat($("#cost_apology").val()) || 0;
      var cost_labor_reshipment = parseFloat($("#cost_labor_reshipment").val()) || 0;
      var reshipment = parseFloat($("#reshipment").val()) || 0;
      var cost_ship_replacement = parseFloat($("#cost_ship_replacement").val()) || 0;
      var cost_of_comm = parseFloat($("#cost_of_comm").val()) || 0;
      // var return_ship = parseFloat($("#return_ship").val()) || 0;
      // var product_abandonment = parseFloat($("#product_abandonment").val()) || 0;
      // var calc_cost = parseFloat($("#calc_cost").val()) || 0;
      // var future_calc_cost = parseFloat($("#future_calc_cost").val()) || 0;
      // var life_long_calc_cost = parseFloat($("#life_long_calc_cost").val()) || 0;
      var total_international = parseFloat($("#total_international").val()).toFixed(2) || 0;
      var total_expedited = parseFloat($("#total_expedited").val()).toFixed(2) || 0;

      $("#total_replacement_costs").html(parseFloat(cost_ship_replacement + reshipment + cost_labor_reshipment + cost_apology + total_expedited + total_international).toFixed(2));
      $("#total_replacement_costs").val(parseFloat(cost_ship_replacement + reshipment + cost_labor_reshipment + cost_apology + total_expedited + total_international).toFixed(2));

      var error_per_day = $("#error_per_day").val();
      var total_cost_per_error = $("#total_cost_per_error").val();
      $("#daily_cost_error").html(parseFloat(total_cost_per_error*error_per_day).toFixed(2));
      $("#daily_cost_error").val(parseFloat(total_cost_per_error*error_per_day).toFixed(2));
    });

    $(document).on('change paste keyup input', function(){
      var packing_days_per_month = $('#packing_days_per_month').val();
      var daily_cost_error = $("#daily_cost_error").val();
      $("#monthly_error_cost").html(parseFloat(daily_cost_error*packing_days_per_month).toFixed(2));
      $("#monthly_error_cost").val(parseFloat(daily_cost_error*packing_days_per_month).toFixed(2));

      var monthly_error_cost = $("#monthly_error_cost").val();
      var cost_of_plan = $("#cost_of_plan").val();
      $("#expected_savings").html(parseFloat(monthly_error_cost - cost_of_plan));
      $("#expected_savings").val(parseFloat(monthly_error_cost - cost_of_plan));
    });

    $("#expedited_percentage, #international_percentage").on('change paste keyup input', function(){
      var expedited_percentage = $('#expedited_percentage').val();
      var international_percentage = $('#international_percentage').val();
      $('#international_count').val(parseFloat(100/international_percentage).toFixed(2));
      $('#expedited_count').val(parseFloat(100/expedited_percentage).toFixed(2));
    });

    $("#expedited_count, #international_count").on('change paste keyup input', function(){
      var expedited_count = $('#expedited_count').val();
      var international_count = $('#international_count').val();
      $('#international_percentage').val(parseFloat(100/international_count).toFixed(2));
      $('#expedited_percentage').val(parseFloat(100/expedited_count).toFixed(2));
    });

    $(document).on('change paste keyup input', function(){
      var expedited_percentage = $('#expedited_percentage').val();
      var expedited_avg = $('#expedited_avg').val();
      if (expedited_percentage != null && expedited_avg != null){
        $('#total_expedited').val(parseFloat(expedited_percentage*expedited_avg/100).toFixed(2))
      }
    });

    $(document).on('change paste keyup input', function(){
      var international_percentage = $('#international_percentage').val();
      var avg_order_profit = $('#avg_order_profit').val();
      if (international_percentage != null && avg_order_profit != null){
        $('#total_international').val(parseFloat(international_percentage*avg_order_profit/100).toFixed(2))
      }
    });

    $(document).on('change paste keyup input', 'input', function() {
      var error_per_day = $("#error_per_day").val();
      var total_cost_per_error = $("#total_cost_per_error").val();
      $("#daily_cost_error").html(parseFloat(total_cost_per_error*error_per_day).toFixed(2));
      $("#daily_cost_error").val(parseFloat(total_cost_per_error*error_per_day).toFixed(2));
    });

    $(document).on('change paste keyup input', function(){
      var total_error_shipment = parseFloat($('#total_error_shipment').val()) || 0;
      var product_abandonment_percentage = parseFloat($('#product_abandonment_percentage').val()) || 0;
      var avg_product_abandonment = parseFloat($('#avg_product_abandonment').val()) || 0;
      var return_shipping_percentage = parseFloat($('#return_shipping_percentage').val()) || 0;
      var cost_return = parseFloat($('#cost_return').val()) || 0;
      var return_shipping_cost = parseFloat($('#return_shipping_cost').val()) || 0;
      var return_shipping_insurance = parseFloat($('#return_shipping_insurance').val()) || 0;
      var cost_recieving_process = parseFloat($('#cost_recieving_process').val()) || 0;
      var cost_confirm = parseFloat($('#cost_confirm').val()) || 0;

      $('#return_shipment_or_abandonment').html(
        parseFloat((total_error_shipment/100)*((product_abandonment_percentage*avg_product_abandonment/100) + ((return_shipping_percentage/100)*(cost_return + return_shipping_cost + return_shipping_insurance + cost_recieving_process + cost_confirm)))).toFixed(2));
      $('#return_shipment_or_abandonment').val(
        parseFloat((total_error_shipment/100)*((product_abandonment_percentage*avg_product_abandonment/100) + ((return_shipping_percentage/100)*(cost_return + return_shipping_cost + return_shipping_insurance + cost_recieving_process + cost_confirm)))).toFixed(2));
    });


    $('#incorrect_current_order, #incorrect_lifetime_order, #negative_shipment, #inventory_shortage_order').on('change paste keyup input', function(){
      var incorrect_current_order = parseFloat($('#incorrect_current_order').val()) || 0; 
      var incorrect_lifetime_order = parseFloat($('#incorrect_lifetime_order').val()) || 0;
      var negative_shipment = parseFloat($('#negative_shipment').val()) || 0;
      var inventory_shortage_order = parseFloat($('#inventory_shortage_order').val()) || 0;
      if(incorrect_current_order != null){
        $('#incorrect_current_order_per').html(parseFloat(100/incorrect_current_order).toFixed(2))
        $('#incorrect_current_order_per').val(parseFloat(100/incorrect_current_order).toFixed(2))
      }
      if(incorrect_lifetime_order != null){
        $('#incorrect_lifetime_order_per').html(parseFloat(100/incorrect_lifetime_order).toFixed(2))
        $('#incorrect_lifetime_order_per').val(parseFloat(100/incorrect_lifetime_order).toFixed(2))
      }
      if(negative_shipment != null){
        $('#negative_shipment_per').html(parseFloat(100/negative_shipment).toFixed(2))
        $('#negative_shipment_per').val(parseFloat(100/negative_shipment).toFixed(2))
      }
      if(inventory_shortage_order != null){
        $('#inventory_shortage_order_per').html(parseFloat(100/inventory_shortage_order).toFixed(2))
        $('#inventory_shortage_order_per').val(parseFloat(100/inventory_shortage_order).toFixed(2))
      }
    });

    $('#incorrect_current_order_per, #incorrect_lifetime_order_per, #negative_shipment_per, #inventory_shortage_order_per').on('change paste keyup input', function(){
      var incorrect_current_order_per = parseFloat($('#incorrect_current_order_per').val()) || 0; 
      var incorrect_lifetime_order_per = parseFloat($('#incorrect_lifetime_order_per').val()) || 0;
      var negative_shipment_per = parseFloat($('#negative_shipment_per').val()) || 0;
      var inventory_shortage_order_per = parseFloat($('#inventory_shortage_order_per').val()) || 0;
      if(incorrect_current_order_per != null){
        $('#incorrect_current_order').html(parseFloat(100/incorrect_current_order_per).toFixed(2))
        $('#incorrect_current_order').val(parseFloat(100/incorrect_current_order_per).toFixed(2))
      }
      if(incorrect_lifetime_order_per != null){
        $('#incorrect_lifetime_order').html(parseFloat(100/incorrect_lifetime_order_per).toFixed(2))
        $('#incorrect_lifetime_order').val(parseFloat(100/incorrect_lifetime_order_per).toFixed(2))
      }
      if(negative_shipment_per != null){
        $('#negative_shipment').html(parseFloat(100/negative_shipment_per).toFixed(2))
        $('#negative_shipment').val(parseFloat(100/negative_shipment_per).toFixed(2))
      }
      if(inventory_shortage_order_per != null){
        $('#inventory_shortage_order').html(parseFloat(100/inventory_shortage_order_per).toFixed(2))
        $('#inventory_shortage_order').val(parseFloat(100/inventory_shortage_order_per).toFixed(2))
      }
    });


    $('#avg_current_order, #lifetime_val, #incorrect_current_order_per, #incorrect_lifetime_order_per, #negative_shipment_per, #inventory_shortage_order_per, #incorrect_current_order, #incorrect_lifetime_order, #negative_shipment, #inventory_shortage_order, #misc_cost').on('change paste keyup input', function(){
      var incorrect_current_order_per = parseFloat($('#incorrect_current_order_per').val()) || 0;
      var avg_current_order = parseFloat($('#avg_current_order').val()) || 0;
      var incorrect_lifetime_order_per = parseFloat($('#incorrect_lifetime_order_per').val()) || 0;
      var lifetime_val = parseFloat($('#lifetime_val').val()) || 0;
      var negative_shipment_per = parseFloat($('#negative_shipment_per').val()) || 0;
      var inventory_shortage_order_per = parseFloat($('#inventory_shortage_order_per').val()) || 0;

      if(incorrect_current_order_per != null && avg_current_order != null){
        $('#cancel_order_shipment').val(parseFloat(incorrect_current_order_per*avg_current_order/100).toFixed(2));
        $('#cancel_order_shipment').html(parseFloat(incorrect_current_order_per*avg_current_order/100).toFixed(2));
      }
      if(incorrect_lifetime_order_per != null && lifetime_val != null){
        $('#lifetime_order_val').val(parseFloat(incorrect_lifetime_order_per*lifetime_val/100).toFixed(2));
        $('#lifetime_order_val').html(parseFloat(incorrect_lifetime_order_per*lifetime_val/100).toFixed(2));
      }
      if(negative_shipment_per != null && lifetime_val != null){
        $('#negative_post_review').val(parseFloat(parseFloat(negative_shipment_per).toFixed(2)*parseFloat(lifetime_val).toFixed(2)/100).toFixed(2));
        $('#negative_post_review').html(parseFloat(parseFloat(negative_shipment_per).toFixed(2)*parseFloat(lifetime_val).toFixed(2)/100).toFixed(2));
      }
      if(inventory_shortage_order_per != null && avg_current_order != null){
        $('#inventory_shortage').val(parseFloat(inventory_shortage_order_per*avg_current_order/100).toFixed(2));
        $('#inventory_shortage').html(parseFloat(inventory_shortage_order_per*avg_current_order/100).toFixed(2));
      }

      var misc_cost = parseFloat($('#misc_cost').val()) || 0;
      var cancel_order_shipment = parseFloat($('#cancel_order_shipment').val()) || 0;
      var lifetime_order_val = parseFloat($('#lifetime_order_val').val()) || 0;
      var negative_post_review = parseFloat($('#negative_post_review').val()) || 0;
      var inventory_shortage = parseFloat($('#inventory_shortage').val()) || 0;
      $('#intangible_cost').html(parseFloat(misc_cost + cancel_order_shipment + negative_post_review + lifetime_order_val + inventory_shortage).toFixed(2))
      $('#intangible_cost').val(parseFloat(misc_cost + cancel_order_shipment + negative_post_review + lifetime_order_val + inventory_shortage).toFixed(2))
    });

    $(document).on('change paste keyup input', 'input', function() {  
      calculate_values();
    });

    $(document).ready(function(){
      $('#misc_cost').change();
      $('#packer_count').change();
      $('#incorrect_current_order').change();
      calculate_values();
    });   

    function calculate_values() {
      var intangible_cost = parseFloat($('#intangible_cost').val()) || 0;
      var return_shipment_or_abandonment = parseFloat($('#return_shipment_or_abandonment').val()) || 0;
      var total_replacement_costs = parseFloat($('#total_replacement_costs').val()) || 0;
      var cost_of_comm = parseFloat($('#cost_of_comm').val()) || 0;
      $('#total_cost').html(parseFloat(intangible_cost + return_shipment_or_abandonment + total_replacement_costs + cost_of_comm).toFixed(2))
      $('#total_cost').val(parseFloat(intangible_cost + return_shipment_or_abandonment + total_replacement_costs + cost_of_comm).toFixed(2))

      var total_cost = parseFloat($('#total_cost').val()) || 0;
      var error_per_day = parseFloat($("#error_per_day").val()) || 0;
      $('#error_cost_per_day').html(parseFloat(total_cost*error_per_day).toFixed(2));
      $('#error_cost_per_day').val(parseFloat(total_cost*error_per_day).toFixed(2));

      var error_cost_per_day = parseFloat($('#error_cost_per_day').val()) || 0;      
      $('#monthly_shipping').html(parseFloat(error_cost_per_day*30).toFixed(2));
      $('#monthly_shipping').val(parseFloat(error_cost_per_day*30).toFixed(2))

      var packer_count = parseFloat($('#packer_count').val()) || 0; 
      $('#gp_cost').html(parseFloat(packer_count*50));
      $('#gp_cost').val(parseFloat(packer_count*50));

      var gp_cost = parseFloat($('#gp_cost').val()) || 0;
      var monthly_shipping = parseFloat($('#monthly_shipping').val()) || 0;
      $('#monthly_saving').html(parseFloat(monthly_shipping - gp_cost).toFixed(2));
      $('#monthly_saving').val(parseFloat(monthly_shipping - gp_cost).toFixed(2))
      $('#lifetime_value').val($('#lifetime_val').val());
      $('#avg_current_order_val').val($('#avg_current_order').val());
      $('#lifetime_value').html($('#lifetime_val').val());
      $('#avg_current_order_val').html($('#avg_current_order').val());
    }

    $(document).on('change paste keyup input', 'input', function(e) {  
      if (isNaN(parseFloat(this.value)) == true) {
        $(this.id).val(0);
      } else {
        $(this.id).val(parseFloat(this.value).toFixed(2));
      }
    });

    $('#send_calculated_email').on('click', function () {
      send_email();
    });

    var send_email = function () {
      $.ajax({
        type: "GET",
        contentType: "application/json; charset=utf-8",
        url: "/email_calculations?" + $("#cost_calc").serialize(),
        data: {recipient_one: $('#recipient_one').val(), recipient_two: $('#recipient_two').val(),
        recipient_three: $('#recipient_three').val(),
        follow_up_email: $('#follow_up_email').is(':checked'), email_text: $("#email_text").val() },
        dataType: "json"
      });
    }

  });

/* Cost calculator stop*/