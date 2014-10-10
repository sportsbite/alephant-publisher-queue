# Alephant::Publisher::Queue

Static publishing to S3 based on SQS messages.

[![Build Status](https://travis-ci.org/BBC-News/alephant-publisher-queue.png?branch=master)](https://travis-ci.org/BBC-News/alephant-publisher-queue) [![Dependency Status](https://gemnasium.com/BBC-News/alephant-publisher-queue.png)](https://gemnasium.com/BBC-News/alephant-publisher-queue) [![Gem Version](https://badge.fury.io/rb/alephant-publisher-queue.png)](http://badge.fury.io/rb/alephant-publisher-queue)

## Dependencies

- JRuby 1.7.8
- An AWS account (you'll need to create):
  - An S3 bucket
  - An SQS Queue (if no sequence id provided then `sequence_id` will be used)
  - A Dynamo DB table (optional, will attempt to create if can't be found)

## Migrating from [Alephant::Publisher](https://github.com/BBC-News/alephant-publisher)

* The namespace has changed from `Alephant::Publisher` to `Alephant::Publisher::Queue`.
* You will need to run `bundle install`.
* You will need to change how you require the gem (`require 'alephant/publisher/queue'`).

## Installation

Add this line to your application's Gemfile:

    gem 'alephant-publisher-queue'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install alephant-publisher-queue

## Setup

Ensure you have a `config/aws.yml` in the format:

```yaml
access_key_id: ACCESS_KEY_ID
secret_access_key: SECRET_ACCESS_KEY
```

## Usage

**In your application:**

```rb
require 'alephant'

sequential_proc = Proc.new do |last_seen_id, data|
  last_seen_id < data['sequence_id'].to_i
end

set_last_seen_proc = Proc.new do |data|
  data['sequence_id'].to_i
end

opts = {
  :s3_bucket_id         => 'bucket-id',
  :s3_object_path       => 'path/to/object',
  :s3_object_id         => 'object_id',
  :sequencer_table_name => 'your_dynamo_db_table',
  :sqs_queue_url        => 'https://your_amazon_sqs_queue_url',
  :sequential_proc      => sequential_proc,
  :set_last_seen_proc   => set_last_seen_proc,
  :lookup_table_name    => 'your_lookup_table'
}

logger = Logger.new

thread = Alephant::Alephant.new(opts, logger).run!
thread.join
```

Publisher requires both queue options and writer options to be provided. To ensure a standard format you should use the `Options` class to generate your options before passing them onto the Publisher...

```ruby
opts = Alephant::Publisher::Options.new
# => #<Alephant::Publisher::Options:0x0602f958 @queue={}, @writer={}>

opts.queue
# => {}
# empty to start with

opts.writer
# => {}
# empty to start with

opts.add_queue(:foo => "bar")
# The key 'foo' is invalid
# => nil

opts.queue
# => {}
# still empty as the foo key was invalid

opts.add_queue(:sqs_queue_url => "bar")
# => {:sqs_queue_url=>"bar"}

opts.queue
# => {:sqs_queue_url=>"bar"}

opts.add_writer(:sqs_queue_url => "bar")
# The key 'sqs_queue_url' is invalid
# => nil
# the sqs_queue_url key was valid for the queue options,
# but is invalid when trying to add it to the writer options

opts.add_writer(:msg_vary_id_path => "bar")
=> {:msg_vary_id_path=>"bar"}

opts.writer
=> {:msg_vary_id_path=>"bar"}
```

logger is optional, and must confirm to the Ruby standard logger interface

Provide a view in a folder (fixtures are optional):

```
└── views
    ├── models
    │   └── foo.rb
    ├── fixtures
    │   └── foo.json
    └── templates
        └── foo.mustache
```

**SQS Message Format**

```json
{
  "content": "hello world",
  "sequential_id": 1
}
```

**foo.rb**

```rb
module MyApp
  module Views
    class Foo < Alephant::Views::Base
      def content
        @data['content']
      end
    end
  end
end
```

**foo.mustache**

```mustache
{{content}}
```

**S3 Output**

```
hello world
```

## Build the gem locally

If you want to test a modified version of the gem within your application without publishing it then you can follow these steps...

- `gem uninstall alephant-publisher-queue`
- `gem build alephant-publisher-queue.gemspec` (this will report the file generated which you reference in the next command)
- `gem install ./alephant-publisher-queue-0.0.1.gem`

Now you can test the gem from within your application as you've installed the gem from the local version rather than your published version

## Preview Server

`alephant preview`

The included preview server allows you to see the html generated by your
templates, both standalone and in the context of a page.

**Standalone**

`/component/:id/?:fixture?`

### Full page preview

When viewing the component in the context of a page, you'll need to retrieve a
mustache template to provide the page context.

When performing an update a regex is applied to replace the static hostnames in
the retrieved html.

**Environment Variables**

```sh
STATIC_HOST_REGEX="static.(sandbox.dev|int|test|stage|live).yourapp(i)?.com\/"
PREVIEW_TEMPLATE_URL="http://yourapp.com/template"
```

**Example Remote Template**

`id` is the component/folder name  

`template` is the mustache template file name  

`location_in_page` should be something like (for example) `page_head` (specified within a `preview.mustache` file that the consuming application needs to create).

- `http://localhost:4567/component/id/template`
- `http://localhost:4567/preview/id/template/location_in_page`

`alephant update`

**In page**

`/preview/:id/:region/?:fixture?`

## Contributing

1. [Fork it!](http://github.com/BBC-News/alephant-publisher-queue/fork)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
