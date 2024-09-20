# spec/jobs/order_tagging_job_spec.rb

require 'rails_helper'

RSpec.describe OrderTaggingJob, type: :job do
  let(:tag) { create(:order_tag) } # Assuming a factory for OrderTag exists
  let(:tag_id) { [tag.id] }
  let(:store) { create(:store, :csv) }
  let(:order_status) { 'awaiting' }
  let(:order) { create(:order, increment_id: 'Test Verify Order', status: order_status, store: store) }
  let(:orders) do
    [
      create(:order, increment_id: 'Test Verify Order', status: order_status, store: store),
      create(:order, increment_id: 'Test Verify Order 1', status: order_status, store: store),
      create(:order, increment_id: 'Test Verify Order 2', status: order_status, store: store),
      create(:order, increment_id: 'Test Verify Order 3', status: order_status, store: store),
      create(:order, increment_id: 'Test Verify Order 4', status: order_status, store: store)
    ]
  end
  let(:order_ids) { orders.map(&:id) }

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

        # expect($redis).to have_received(:get).with("order_tagging_job:groove_bulk_tags_actions")

        expect(GroovRealtime).to have_received(:emit).with("pnotif", {:data=>0, :type=>"groove_bulk_tags_actions"}, :tenant)
      end

      it 'calls the necessary methods remove tags' do
        OrderTaggingJob.perform_now([tag_id], order_ids, 'remove', total_batches)

        # expect($redis).to have_received(:get).with("order_tagging_job:groove_bulk_tags_actions")

        expect(GroovRealtime).to have_received(:emit).with("pnotif", {:data=>0, :type=>"groove_bulk_tags_actions"}, :tenant)
      end
        it 'emits the cancellation event and returns an error' do
          # Mock the cancel condition
          allow($redis).to receive(:get).with("order_tagging_job:cancel").and_return("true")
          
          # Call the job
          result = OrderTaggingJob.perform_now([tag_id], order_ids, 'add', total_batches)

          # Verify that GroovRealtime.emit is called with the correct arguments
          expect(GroovRealtime).to have_received(:emit).with(
            'pnotif',
            { type: 'groove_bulk_tags_actions', data: 100 },
            :tenant
          )

          # Check that the method returns the expected error
          expect(result).to eq({ error: 'Tagging process canceled' })
        end
    end
  end
end
