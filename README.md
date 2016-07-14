# Alephant::Publisher::Queue

Static publishing to S3 based on SQS messages.

[![Build Status](https://travis-ci.org/BBC-News/alephant-publisher-queue.png?branch=master)](https://travis-ci.org/BBC-News/alephant-publisher-queue) [![Dependency Status](https://gemnasium.com/BBC-News/alephant-publisher-queue.png)](https://gemnasium.com/BBC-News/alephant-publisher-queue) [![Gem Version](https://badge.fury.io/rb/alephant-publisher-queue.png)](http://badge.fury.io/rb/alephant-publisher-queue)

## Dependencies

- JRuby 1.7.8+
- An AWS account, with:
  - S3 bucket.
  - SQS Queue.
  - Dynamo DB table.
  - Elasticache (if using the "revalidate" pattern)

## Migrating from [Alephant::Publisher](https://github.com/BBC-News/alephant-publisher)

Add the new gem in your Gemfile:

```
gem 'alephant-publisher-queue'
```

Run:

```
bundle install
```

Require the new gem in your app:

```
require 'alephant/publisher/queue'
```

**Important** - note that the namespace has changed from `Alephant::Publisher` to `Alephant::Publisher::Queue`.

## Installation

Add this line to your application's Gemfile:

```
gem 'alephant-publisher-queue'
```

And then execute:

```
bundle
```

Or install it yourself as:

```
gem install alephant-publisher-queue
```

## Setup

Ensure you have a `config/aws.yml` in the format:

```yaml
access_key_id: ACCESS_KEY_ID
secret_access_key: SECRET_ACCESS_KEY
```

## Structure

Provide a view and template:

```
└── views
    ├── models
    │   └── foo.rb
    └── templates
        └── foo.mustache
```

**foo.rb**

```ruby
class Foo < Alephant::Views::Base
  def content
    @data['content']
  end
end
```

**foo.mustache**

```
{{ content }}
```

## Usage (standard setup - non-revalidate)

```ruby
require "alephant/logger"
require "alephant/publisher/queue"

module MyApp
  def self.run!
    loop do
      Alephant::Publisher::Queue.create(options).run!
    end
  rescue => e
    Alephant::Logger.get_logger.error "Error: #{e.message}"
  end

  private

  def self.options
    Alephant::Publisher::Queue::Options.new.tap do |opts|
      opts.add_queue(
        :aws_account_id => 'example',
        :sqs_queue_name => 'test_queue'
      )
      opts.add_writer(
        :keep_all_messages    => 'false',
        :lookup_table_name    => 'lookup-dynamo-table',
        :renderer_id          => 'renderer-id',
        :s3_bucket_id         => 'bucket-id',
        :s3_object_path       => 'example-s3-path',
        :sequence_id_path     => '$.sequential_id',
        :sequencer_table_name => 'sequence-dynamo-table',
        :view_path            => 'path/to/views'
      )
    end
  end
end
```

Add a message to your SQS queue, with the following format:

```json
{
  "content": "Hello World!",
  "sequential_id": 1
}
```

Output:

```
Hello World!
```

S3 Path:

```
S3 / bucket-id / example-s3-path / renderer-id / foo / 7e0c33c476b1089500d5f172102ec03e / 1
```

## Usage (revalidate pattern)

```ruby
require "addressable/uri"
require "alephant/logger"
require "alephant/publisher/queue"

module MyApp
  class UrlGenerator
    class << self
      # This function is called to generate the URL to be requested as
      # part of the rendering process. The return must be a URL as a string.
      def generate(opts)
        "http://example.com/?#{url_params(opts)}"
      end

      private

      def url_params(params_hash)
        uri = Addressable::URI.new
        uri.query_values = params_hash
        uri.query
      end
    end
  end

  class HttpResponseProcessor
    class << self
      # This function is called upon a successful HTTP response.
      #
      # Use it to modify or process the response of your HTTP request
      # as you please, but there is one rule - the return value MUST
      # be a JSON object.
      def process(opts, status, body)
        # our response is already JSON, pass it through
        body
      end

      # If you wish to vary your revalidate TTL on a per-endpoint (or
      # other logic) basis, you can do it here - simply return an Integer
      # value.
      #
      # If nil is returned the 'revalidate_cache_ttl' config setting on the
      # broker will be used as the default TTL, otherwise the default in
      # 'alephant-broker' will be used.
      def self.ttl(opts)
        # 30s revalidate time for all
        30
      end
    end
  end

  def self.run!
    loop do
      Alephant::Publisher::Queue.create(options, processor).run!
    end
  rescue => e
    Alephant::Logger.get_logger.error "Error: #{e.message}"
  end

  private

  def self.processor
    Alephant::Publisher::Queue::RevalidateProcessor.new(options, UrlGenerator, HttpResponseProcessor)
  end

  def self.options
    Alephant::Publisher::Queue::Options.new.tap do |opts|
      opts.add_queue(
        :aws_account_id => 'example',
        :sqs_queue_name => 'test_queue'
      )
      opts.add_writer(
        :lookup_table_name    => 'lookup-dynamo-table',
        :s3_bucket_id         => 'bucket-id',
        :s3_object_path       => 'example-s3-path',
        :view_path            => 'path/to/views'
      )
      opts.add_cache(
        :elasticache_config_endpoint => 'example',
        :elasticache_cache_version   => '100',
        :revalidate_cache_ttl        => '30'
      )
    end
  end
end
```

Add a message to your SQS queue, with the following format (`id`, `batch_id`, `options`):

```json
{
  "id": "renderer_id",
  "batch_id": null,
  "options": {
    "id": "foo",
    "type": "chart"
  }
}
```

This will then make a HTTP GET request to the configured endpoint (via `UrlGenerator`), process the response (via `HttpResponseProcessor`), render and store your content.

You will not ordinarily need to push messages onto SQS manually, this will be handled via the broker in real use.

## Preview Server

[Alephant Preview](https://github.com/BBC-News/alephant-preview) allows you to see the HTML generated by your templates, both standalone and in the context of a page.

## Contributing

1. [Fork it!](http://github.com/BBC-News/alephant-publisher-queue/fork)
2. Create your feature branch: `git checkout -b my-new-feature`
3. Commit your changes: `git commit -am 'Add some feature'`
4. Push to the branch: `git push origin my-new-feature`
5. Create new [Pull Request](https://github.com/BBC-News/alephant-publisher-queue/compare).

Feel free to create an [issue](https://github.com/BBC-News/alephant-publisher-queue/issues/new) if you find a bug.
