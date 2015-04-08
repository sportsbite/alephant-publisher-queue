require "spec_helper"
require "aws-sdk"
require "ostruct"

describe Alephant::Publisher::Queue::Publisher do
  context "controlling archiving" do
    let(:queue_config) { {} }
    let(:config) { instance_double(Alephant::Publisher::Queue::Options, :queue => queue_config) }

    context "enabled" do
      let(:instance) { described_class.new(config) }
      specify { expect(instance.queue.archiver).to be_a Alephant::Publisher::Queue::SQSHelper::Archiver }
    end

    context "disabled" do
      before(:each) do
        queue_config[:archive_messages] = false
      end
      let(:instance) { described_class.new(config) }
      specify { expect(instance.queue.archiver).to_not be_a Alephant::Publisher::Queue::SQSHelper::Archiver }
    end
  end
end

