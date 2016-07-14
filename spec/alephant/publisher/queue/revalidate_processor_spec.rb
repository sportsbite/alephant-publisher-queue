require 'spec_helper'

RSpec.describe Alephant::Publisher::Queue::RevalidateProcessor do
  class TestUrlGenerator
    def self.generate(_opts = {})
      'http://example.com'
    end
  end

  class TestHttpResponseProcessor
    def self.process(_opts, _response_status, response_body)
      response_body
    end

    def self.ttl(_opts)
      nil
    end
  end

  subject { described_class.new(opts, url_generator, http_response_processor) }

  let(:url_generator)           { TestUrlGenerator }
  let(:http_response_processor) { TestHttpResponseProcessor }

  let(:opts) do
    instance_double(Alephant::Publisher::Queue::Options,
      writer: {},
      cache:  { elasticache_config_endpoint: 'wibble' })
  end

  let(:writer_double)      { instance_double(Alephant::Publisher::Queue::RevalidateWriter, run!: nil) }
  let(:cache_double)       { instance_double(Dalli::Client, delete: nil) }
  let(:elasticache_double) { instance_double(Dalli::ElastiCache, client: cache_double) }

  let(:message)      { instance_double(AWS::SQS::ReceivedMessage, body: JSON.generate(message_body), delete: nil) }
  let(:message_body) { { id: '', batch_id: '', options: {} } }

  before do
    allow(Alephant::Publisher::Queue::RevalidateWriter)
      .to receive(:new)
      .and_return(writer_double)

    allow(Dalli::ElastiCache)
      .to receive(:new)
      .and_return(elasticache_double)
  end

  describe '#consume' do
    context 'when there is a message passed through' do
      context 'when the HTTP request is successful' do
        let(:resp_double) { double(body: resp_body, status: resp_status) }
        let(:resp_body)   { JSON.generate(id: 'foo') }
        let(:resp_status) { 200 }

        before do
          allow(Faraday).to receive(:get).and_return(resp_double)
        end

        it 'calls #run! on the writer with the http request result' do
          expect(Alephant::Publisher::Queue::RevalidateWriter)
            .to receive(:new)
            .with(opts.writer, anything)
            .and_return(writer_double)

          expect(writer_double).to receive(:run!)

          subject.consume(message)
        end

        it 'passes the response to the http_response_processor' do
          expect(http_response_processor)
            .to receive(:process)
            .with(message_body, resp_status, resp_body)
            .and_call_original

          subject.consume(message)
        end

        it "calls the 'ttl' method on the http_response_processor" do
          expect(http_response_processor)
            .to receive(:ttl)
            .with(message_body)
            .and_call_original

          subject.consume(message)
        end

        it 'deletes the message from the queue' do
          expect(message).to receive(:delete)

          subject.consume(message)
        end

        it "removes the 'inflight' cache message" do
          expect(cache_double).to receive(:delete)

          subject.consume(message)
        end
      end

      context 'when the HTTP request is unsuccessful' do
        before do
          allow(Faraday).to receive(:get).and_raise(Faraday::TimeoutError)
        end

        it 'does not call #run! on the writer' do
          expect(writer_double).to_not receive(:run!)

          expect { subject.consume(message) }
            .to raise_error(Faraday::TimeoutError)
        end

        it 'does NOT delele the message from the queue' do
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

    context 'when there is no message passed through' do
      let(:message) { nil }

      it 'does nothing' do
        expect(writer_double).to_not receive(:run!)
        expect(cache_double).to_not receive(:delete)

        subject.consume(message)
      end
    end
  end
end
