require "spec_helper"

describe Alephant::Publisher::Queue::SQSHelper::Archiver do
  let (:storage)  { instance_double("Alephant::Storage", :put => nil) }
  let (:queue)    { instance_double("AWS::SQS::Queue", :url => nil) }
  let (:msg_body) {{ :Message => JSON.generate(msg_uri) }}
  let (:msg_uri)  {{ :uri => "/content/asset/newsbeat" }}
  let (:message) do
    instance_double(
      "AWS::SQS::ReceivedMessage",
      :id    => "id",
      :md5   => "qux",
      :queue => queue,
      :body  => JSON.generate(msg_body)
    )
  end

  let (:opts) do
    {
      :log_archive_message => true,
      :async_store         => false
    }
  end

  let (:subject) { described_class.new(storage, opts) }

  describe "#see" do
    let (:time_now) { DateTime.parse("Feb 24 1981") }

    context "calls storage put with the correct params" do
      before(:each) do
        allow(DateTime).to receive(:now).and_return(time_now)
      end

      specify do
        expect(storage).to receive(:put).with(
          "archive/#{time_now.strftime('%d-%m-%Y_%H')}/id",
          message.body,
          :id        => message.id,
          :md5       => message.md5,
          :logged_at => time_now.to_s,
          :queue     => message.queue.url
        )
        subject.see(message)
      end
    end
  end

  describe "logging archive message" do
    context "enabled" do
      specify do
        subject.see(message)
        expect(message).to have_received(:body).twice
      end
    end

    context "disabled" do
      before(:each) do
        opts[:log_archive_message] = false
      end

      specify do
        subject.see(message)
        expect(message).to have_received(:body).once
      end
    end
  end
end
