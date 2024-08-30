# spec/jobs/order_tagging_job_spec.rb

require 'rails_helper'

RSpec.describe OrderTaggingJob, type: :job do
  let(:tag_id) { 1 }
  let(:order_ids) { [101, 102, 103, 104, 105] }
  let(:total_batches) { 1 }

  before do
    allow($redis).to receive(:incr)
    allow($redis).to receive(:get).and_return("1")
    allow($redis).to receive(:del)

    allow(GroovRealtime).to receive(:emit)
  end

  describe '#perform' do
    context 'when adding tags' do
      it 'calls the necessary methods' do
        OrderTaggingJob.perform_now([tag_id], order_ids, 'add', total_batches)

        expect($redis).to have_received(:incr).with("order_tagging_job:completed_batches")
        expect($redis).to have_received(:get).with("order_tagging_job:completed_batches")

        expect(GroovRealtime).to have_received(:emit).with('pnotif', { type: 'groove_bulk_tags_actions', data: 100 }, :tenant)
      end
    end
  end
end
