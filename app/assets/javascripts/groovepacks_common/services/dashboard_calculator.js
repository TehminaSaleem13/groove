groovepacks_services.factory('dashboard_calculator', ['$http', 'notification', function ($http, notification) {
  var main_summary = function (message, main_summary, days) {
    for (var i = message.data.length - 1; i >= 0; i--) {
      if (message.data[i].duration == days) {
        main_summary.packed_items_summary = {};
        main_summary.packing_speed_summary = {};
        main_summary.packing_accuracy_summary = {};
        main_summary.packed_items_summary.current_period = message.data[i].total_packed;
        main_summary.packed_items_summary.previous_period = message.data[i].prev_total_packed;
        main_summary.packed_items_summary.delta = parseInt(message.data[i].total_packed, 10) - parseInt(message.data[i].prev_total_packed, 10);

        main_summary.packing_speed_summary.current_period = message.data[i].packing_speed;
        main_summary.packing_speed_summary.previous_period = message.data[i].prev_packing_speed;
        main_summary.packing_speed_summary.delta = parseInt(message.data[i].packing_speed, 10) - parseInt(message.data[i].prev_packing_speed, 10);

        main_summary.packing_accuracy_summary.current_period = message.data[i].accuracy;
        main_summary.packing_accuracy_summary.previous_period = message.data[i].prev_accuracy;
        main_summary.packing_accuracy_summary.delta = parseFloat(message.data[i].accuracy, 10) - parseInt(message.data[i].prev_accuracy, 10);
      };
    };
  };

  var leader_board = function (message) {
    console.log("message");
    console.log(message);
    learder_list = []
    console.log(message.data.length);
    for (var i = 0; i <= message.data.length - 1; i++) {
      record = {}
      console.log('recording...');
      record.increment_id = message.data[i].order_number;
      record.order_items_count = message.data[i].order_item_count;
      record.packing_time = message.data[i].packing_time;
      record.record_date = message.data[i].record_date;
      record.user_name = message.data[i].packing_user;
      learder_list.push(record);
    };
    console.log(learder_list);
    return learder_list;
  };

  return {
    stats: {
      main_summary: main_summary,
      leader_board: leader_board
    }
  };
}]);