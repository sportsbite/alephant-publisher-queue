require "spec_helper"

describe Alephant::Publisher::Queue do
  let(:options)       { Alephant::Publisher::Queue::Options.new }
  let(:queue)         { double("AWS::SQS::Queue", :url => nil ) }
  let(:client_double) { double("AWS::SQS", :queues => queue_double) }
  let(:queue_double)  {
    double("AWS::SQS::QueueCollection", :[] => queue, :url_for => nil)
  }

  before(:each) do
    expect(AWS::SQS).to receive(:new).and_return(client_double)
  end

  describe ".create" do
    it "sets parser, sequencer, queue and writer" do
      instance = Alephant::Publisher::Queue.create(options)
      expect(instance.queue)
        .to be_a Alephant::Publisher::Queue::SQSHelper::Queue
    end

    context "with account" do
      it "creates a queue with an account number in the option hash" do
        options = Alephant::Publisher::Queue::Options.new
        options.add_queue(
          :sqs_queue_name => "bar",
          :aws_account_id => "foo"
        )

        expect(queue_double).to receive(:url_for).with(
          "bar",
          :queue_owner_aws_account_id => "foo"
        )

        Alephant::Publisher::Queue.create(options)
      end
    end

    context "without account" do
      it "creates a queue with an empty option hash" do
        options = Alephant::Publisher::Queue::Options.new
        options.add_queue(:sqs_queue_name => "bar")

        expect(queue_double).to receive(:url_for).with("bar", {})

        Alephant::Publisher::Queue.create(options)
      end
    end
  end
end
