# frozen_string_literal: true

module ScanPack
  module ProductFirstScan
    class Base < ScanPack::Base
      attr_accessor :params, :current_user, :scanpack_setting

      def initialize(current_user, session, params)
        set_scan_pack_action_instances(current_user, session, params)
        @scanpack_setting = ScanPackSetting.last
      end

      private

      def tote_identifier
        @tote_identifier ||= scanpack_setting.tote_identifier
      end
    end
  end
end
