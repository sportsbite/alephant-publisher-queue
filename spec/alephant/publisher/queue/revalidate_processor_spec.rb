require "spec_helper"

RSpec.describe Alephant::Publisher::Queue::RevalidateProcessor do
  class TestUrlGenerator
    def self.generate(_opts = {})
      "http://example.com"
    end
  end

  subject { described_class.new(opts, url_generator) }

  let(:url_generator) { TestUrlGenerator }

  let(:opts) do
    instance_double(Alephant::Publisher::Queue::Options,
      :writer => {},
      :cache  => { :elasticache_config_endpoint => "wibble" })
  end

  let(:writer_double) do
    instance_double(Alephant::Publisher::Queue::Writer, :run! => nil)
  end

  let(:cache_double) do
    instance_double(Dalli::Client, :delete => nil)
  end

  let(:elasticache_double) do
    instance_double(Dalli::ElastiCache, :client => cache_double)
  end

  let(:message) do
    instance_double(AWS::SQS::ReceivedMessage,
      :body   => JSON.generate(:id => "", :batch_id => "", :options => {}),
      :delete => nil)
  end

  before do
    allow(Alephant::Publisher::Queue::Writer)
      .to receive(:new)
      .and_return(writer_double)

    allow(Dalli::ElastiCache)
      .to receive(:new)
      .and_return(elasticache_double)
  end

  describe "#consume" do
    context "when there is a message passed through" do
      context "when the HTTP request are successful" do
        let(:response_double) { double(:body => resp_body, :status => resp_status) }
        let(:resp_body)       { JSON.generate(:id => "foo") }
        let(:resp_status)     { 200 }

        before do
          allow(Faraday).to receive(:get).and_return(response_double)
        end

        it "calls #run! on the writer with the http request result" do
          expect(Alephant::Publisher::Queue::Writer)
            .to receive(:new)
            .with(opts.writer, anything)
            .and_return(writer_double)

          expect(writer_double).to receive(:run!)

          subject.consume(message)
        end

        it "deletes the message from the queue" do
          expect(message).to receive(:delete)

          subject.consume(message)
        end

        it "removes the 'inflight' cache message" do
          expect(cache_double).to receive(:delete)

          subject.consume(message)
        end
      end

      context "when the HTTP request is unsuccessful" do
        before do
          allow(Faraday).to receive(:get).and_raise(Faraday::TimeoutError)
        end

        it "does not call #run! on the writer" do
          expect(writer_double).to_not receive(:run!)

          expect { subject.consume(message) }
            .to raise_error(Faraday::TimeoutError)
        end

        it "does NOT delele the message from the queue" do
          expect(message).to_not receive(:delete)

          expect { subject.consume(message) }
            .to raise_error(Faraday::TimeoutError)
        end

        it "does not remove the 'inflight' cache message" do
          expect(cache_double).to_not receive(:delete)

          expect { subject.consume(message) }
            .to raise_error(Faraday::TimeoutError)
        end
      end
    end

    context "when there is no message passed through" do
      let(:message) { nil }

      it "does nothing" do
        expect(writer_double).to_not receive(:run!)
        expect(message).to_not receive(:delete)
        expect(cache_double).to_not receive(:delete)

        subject.consume(message)
      end
    end
  end
end
