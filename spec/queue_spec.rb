require "spec_helper"
require "aws-sdk"

describe Alephant::Publisher::Queue::SQSHelper::Queue do
  describe "#message" do
    it "returns a message" do
      m = double("message").as_null_object
      q = double("queue").as_null_object

      expect(q).to receive(:receive_message).and_return(m)

      instance = Alephant::Publisher::Queue::SQSHelper::Queue.new(q)

      expect(instance.message).to eq(m)
    end

    context "archiving" do
      let(:archiver) { instance_double(Alephant::Publisher::Queue::SQSHelper::Archiver, :see => nil) }
      let(:message) { instance_double(AWS::SQS::ReceivedMessage, :id => nil) }
      let(:queue) { instance_double(AWS::SQS::Queue, :url => nil, :receive_message => message) }
      let(:instance) { Alephant::Publisher::Queue::SQSHelper::Queue.new(queue, archiver) }

      context "enabled" do
        specify do
          expect(archiver).to receive(:see).with(message)
          instance.message
        end
      end

      context "disabled" do
        let(:instance) { Alephant::Publisher::Queue::SQSHelper::Queue.new(queue, nil) }
        specify do
          expect(archiver).to_not receive(:see).with(message)
          instance.message
        end
      end
    end
  end
end

