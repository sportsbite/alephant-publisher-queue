require 'spec_helper'

RSpec.describe Alephant::Publisher::Queue::RevalidateWriter do
  subject { described_class.new(config, message) }

  let(:config) do
    {
      s3_bucket_id:      'qwerty',
      s3_object_path:    'hello/int',
      lookup_table_name: 'lookup_table'
    }
  end

  let(:message)        { double(body: JSON.generate(message_body)) }
  let(:http_response)  { { ticker: 'WMT', val: 180.00 } }
  let(:ttl)            { 45 }

  let(:message_body) do
    {
      renderer_id:   'hello_world',
      http_options:  { id: 'hello_world', options: { ticker: 'WMT', duration: '1_day' } },
      http_response: JSON.generate(http_response),
      ttl:           ttl
    }
  end

  describe '#run!' do
    let(:storage_double)  { instance_double(Alephant::Cache, put: nil) }
    let(:lookup_double)   { instance_double(Alephant::Lookup::LookupHelper, write: nil) }
    let(:renderer_double) do
      instance_double(Alephant::Renderer::Renderer, views: { hello_world_view: hello_world_view })
    end

    let(:hello_world_view)      { double(render: rendered_content, content_type: rendered_content_type) }
    let(:rendered_content)      { '<h1>Hello, world!</h1>' }
    let(:rendered_content_type) { 'text/html' }

    let(:storage_location) { "hello_world/hello_world_view/#{Crimp.signature(message_body[:http_options])}" }

    before do
      allow(Alephant::Renderer).to receive(:create).and_return(renderer_double)
      allow(Alephant::Cache).to receive(:new).and_return(storage_double)
      allow(Alephant::Lookup).to receive(:create).and_return(lookup_double)
    end

    it 'renders the http_response in the Renderer' do
      expect(renderer_double).to receive(:views).and_return(foo: hello_world_view)
      expect(hello_world_view).to receive(:render)
      expect(hello_world_view).to receive(:content_type)

      subject.run!
    end

    it 'stores the HTTP content in S3 with Alephant::Cache' do
      expect(storage_double)
        .to receive(:put)
        .with(storage_location, rendered_content, rendered_content_type, ttl: ttl)

      subject.run!
    end

    it 'writes the S3 location with Alephant::Lookup' do
      expect(lookup_double)
        .to receive(:write)
        .with(:hello_world_view, message_body[:http_options][:options], 1, storage_location)

      subject.run!
    end
  end

  describe '#renderer' do
    it 'builds an Alephant::Renderer::Renderer object' do
      expect(subject.renderer).to be_a(Alephant::Renderer::Renderer)
    end

    it 'passes through the `renderer_id` from the message' do
      expect(Alephant::Renderer)
        .to receive(:create)
        .with(hash_including(renderer_id: 'hello_world'), http_response)

      subject.renderer
    end
  end

  describe '#storage' do
    it 'builds an Alephant::Cache object' do
      expect(subject.storage).to be_a(Alephant::Cache)
    end
  end

  describe '#lookup' do
    it 'builds an Alephant::Lookup object' do
      expect(subject.lookup).to be_a(Alephant::Lookup::LookupHelper)
    end
  end
end
