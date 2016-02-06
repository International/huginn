module Agents
  class BizarroWebsiteAgent < WebsiteAgent
    can_dry_run!

    description <<-MD
      The Website Agent scrapes a website, XML document, or JSON feed and creates Events based on the results.

      Specify a `url` and select a `mode` for when to create Events based on the scraped data, either `all`, `on_change`, or `merge` (if fetching based on an Event, see below).

      The `url` option can be a single url, or an array of urls (for example, for multiple pages with the exact same structure but different content to scrape).

      The WebsiteAgent can also scrape based on incoming events.

      * Set the `url_from_event` option to a Liquid template to generate the url to access based on the Event.  (To fetch the url in the Event's `url` key, for example, set `url_from_event` to `{{ url }}`.)
      * Alternatively, set `data_from_event` to a Liquid template to use data directly without fetching any URL.  (For example, set it to `{{ html }}` to use HTML contained in the `html` key of the incoming Event.)
      * If you specify `merge` for the `mode` option, Huginn will retain the old payload and update it with new values.

      # Supported Document Types

      The `type` value can be `xml`, `html`, `json`, or `text`.

      To tell the Agent how to parse the content, specify `extract` as a hash with keys naming the extractions and values of hashes.

      Note that for all of the formats, whatever you extract MUST have the same number of matches for each extractor.  E.g., if you're extracting rows, all extractors must match all rows.  For generating CSS selectors, something like [SelectorGadget](http://selectorgadget.com) may be helpful.

      # Scraping HTML and XML

      When parsing HTML or XML, these sub-hashes specify how each extraction should be done.  The Agent first selects a node set from the document for each extraction key by evaluating either a CSS selector in `css` or an XPath expression in `xpath`.  It then evaluates an XPath expression in `value` (default: `.`) on each node in the node set, converting the result into a string.  Here's an example:

          "extract": {
            "url": { "css": "#comic img", "value": "@src" },
            "title": { "css": "#comic img", "value": "@title" },
            "body_text": { "css": "div.main", "value": ".//text()" }
          }

      "@_attr_" is the XPath expression to extract the value of an attribute named _attr_ from a node, and `.//text()` extracts all the enclosed text. To extract the innerHTML, use `./node()`; and to extract the outer HTML, use  `.`.

      You can also use [XPath functions](http://www.w3.org/TR/xpath/#section-String-Functions) like `normalize-space` to strip and squeeze whitespace, `substring-after` to extract part of a text, and `translate` to remove commas from formatted numbers, etc.  Note that these functions take a string, not a node set, so what you may think would be written as `normalize-space(.//text())` should actually be `normalize-space(.)`.

      Beware that when parsing an XML document (i.e. `type` is `xml`) using `xpath` expressions, all namespaces are stripped from the document unless the top-level option `use_namespaces` is set to `true`.

      # Scraping JSON

      When parsing JSON, these sub-hashes specify [JSONPaths](http://goessner.net/articles/JsonPath/) to the values that you care about.  For example:

          "extract": {
            "title": { "path": "results.data[*].title" },
            "description": { "path": "results.data[*].description" }
          }

      The `extract` option can be skipped for the JSON type, causing the full JSON response to be returned.

      # Scraping Text

      When parsing text, each sub-hash should contain a `regexp` and `index`.  Output text is matched against the regular expression repeatedly from the beginning through to the end, collecting a captured group specified by `index` in each match.  Each index should be either an integer or a string name which corresponds to <code>(?&lt;<em>name</em>&gt;...)</code>.  For example, to parse lines of <code><em>word</em>: <em>definition</em></code>, the following should work:

          "extract": {
            "word": { "regexp": "^(.+?): (.+)$", index: 1 },
            "definition": { "regexp": "^(.+?): (.+)$", index: 2 }
          }

      Or if you prefer names to numbers for index:

          "extract": {
            "word": { "regexp": "^(?<word>.+?): (?<definition>.+)$", index: 'word' },
            "definition": { "regexp": "^(?<word>.+?): (?<definition>.+)$", index: 'definition' }
          }

      To extract the whole content as one event:

          "extract": {
            "content": { "regexp": "\A(?m:.)*\z", index: 0 }
          }

      Beware that `.` does not match the newline character (LF) unless the `m` flag is in effect, and `^`/`$` basically match every line beginning/end.  See [this document](http://ruby-doc.org/core-#{RUBY_VERSION}/doc/regexp_rdoc.html) to learn the regular expression variant used in this service.

      # General Options

      Can be configured to use HTTP basic auth by including the `basic_auth` parameter with `"username:password"`, or `["username", "password"]`.

      Set `expected_update_period_in_days` to the maximum amount of time that you'd expect to pass between Events being created by this Agent.  This is only used to set the "working" status.

      Set `uniqueness_look_back` to limit the number of events checked for uniqueness (typically for performance).  This defaults to the larger of #{UNIQUENESS_LOOK_BACK} or #{UNIQUENESS_FACTOR}x the number of detected received results.

      Set `force_encoding` to an encoding name if the website is known to respond with a missing, invalid, or wrong charset in the Content-Type header.  Note that a text content without a charset is taken as encoded in UTF-8 (not ISO-8859-1).

      Set `user_agent` to a custom User-Agent name if the website does not like the default value (`#{default_user_agent}`).

      The `headers` field is optional.  When present, it should be a hash of headers to send with the request.

      Set `disable_ssl_verification` to `true` to disable ssl verification.

      Set `unzip` to `gzip` to inflate the resource using gzip.

      Set `consider_code_success` to an array of ints, ex: `[404]` to consider also 404 as successes, and to scrape it.

      # Liquid Templating

      In Liquid templating, the following variable is available:

      * `_response_`: A response object with the following keys:

          * `status`: HTTP status as integer. (Almost always 200)

          * `headers`: Response headers; for example, `{{ _response_.headers.Content-Type }}` expands to the value of the Content-Type header.  Keys are insensitive to cases and -/_.

      # Ordering Events

      #{description_events_order}
    MD


    def consider_response_successful?(response)
      super || begin
        consider_success = options["consider_code_success"]
        consider_success.present? && consider_success.include?(response.status)
      end
    end
  end
end
