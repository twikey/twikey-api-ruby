require 'net/http'
require 'json'
require 'uri'

module Twikey
  class Error < StandardError; end
  class AuthError < StandardError; end

  class Client
    attr_reader :base_url, :session_token

    def initialize(api_key:, url: 'https://api.twikey.com/creditor')
      @api_key = api_key
      unless url.end_with?('/')
        url = url+ '/'
      end

      @base_url = url
      @session_token = nil
      @auth_time = Time.at(0)
    end

    def ping
      self::authenticate
    end

    def mandates
      @mandates ||= MandateService.new(self)
    end

    def invoices
      @invoices ||= InvoiceService.new(self)
    end

    def transactions
      @transactions ||= TransactionService.new(self)
    end

    def paylinks
      @paylinks ||= PaylinkService.new(self)
    end

    def verify_webhook(signature_header, payload)
      digest = OpenSSL::Digest.new('sha256')
      computed = OpenSSL::HMAC.hexdigest(digest, @api_key, payload).upcase

      if signature_header == computed
        true
      else
        raise Twikey::Error.new("Invalid webhook signature")
      end
    rescue => e
      raise Twikey::Error.new("Failed to verify webhook: #{e.message}")
    end


    def get(path, params = {})
      uri = join_url(@base_url, path)
      uri.query = URI.encode_www_form(params) unless params.empty?
      request = Net::HTTP::Get.new(uri)
      request['Authorization'] = authenticate
      request['Accept'] = 'application/json'
      perform_request(uri, request)
    end

    def get_binary(path, params = {})
      uri = join_url(@base_url, path)
      uri.query = URI.encode_www_form(params) unless params.empty?
      request = Net::HTTP::Get.new(uri)
      request['Authorization'] = authenticate
      request['Accept'] = 'application/pdf'
      perform_binary_request(uri, request)
    end

    def post(path, body = {}, form: false)
      uri = join_url(@base_url, path)
      request = Net::HTTP::Post.new(uri)
      request['Authorization'] = authenticate
      request['Accept'] = 'application/json'
      if form
        request.set_form_data(body)
      else
        request['Content-Type'] = 'application/json'
        request.body = JSON.dump(body)
      end
      perform_request(uri, request)
    end

    private

    def authenticate()
      if @api_key
        if (Time.now - @auth_time) < 43200  #12 hour
          return @session_token
        end

        uri = URI.parse(@base_url)
        request = Net::HTTP::Post.new(uri)
        request.set_form_data({ apiToken: @api_key })

        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = (uri.scheme == 'https')

        response = http.request(request)
        @session_token = response['Authorization']
        if @session_token != nil
          @auth_time = Time.now
          return @session_token
        end
        raise AuthError, "Couldn't log in: #{response.body}"
      end
      raise AuthError, "Couldn't log in: no api_key set"
    end

    def join_url(*parts)
      parts.map.with_index do |part, index|
        index.zero? ? part.to_s.chomp('/') : part.to_s.gsub(%r{(^/|/$)}, '')
      end.join('/')
    end


    def perform_request(uristr, request)
      uri = URI.parse(uristr)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      response = http.request(request)

      case response
      when Net::HTTPSuccess
        JSON.parse(response.body)
      else
        raise Error, "HTTP #{response.code}: #{response.message}\n#{response.body}"
      end
    end

    def perform_binary_request(uristr, request)
      uri = URI.parse(uristr)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      response = http.request(request)

      case response
      when Net::HTTPSuccess
        response.body
      else
        raise Error, "HTTP #{response.code}: #{response.message}\n#{response.body}"
      end
    end
  end


  class Twikey::Feed
    include Enumerable

    def initialize(&fetch_block)
      @fetch_block = fetch_block
      @position = nil
    end

    def each
      loop do
        options = {}
        options[:position] = @position if @position

        page = @fetch_block.call(options)
        break if page.empty?

        page.each do |item|
          yield item
        end

        # Update the position if you track it
        @position = page.last[:position] if page.last && page.last[:position]
      end
    end
  end

  class MandateService
    def initialize(client)
      @client = client
    end

    def feed(params = {})
      Twikey::Feed.new do |options|
        @client.get('/mandate', params)["Messages"]
      end
    end

    def invite(params)
      @client.post('invite', params, form: true)
    end

    def sign(params)
      @client.post('sign', params, form: true)
    end
  end

  class InvoiceService
    def initialize(client)
      @client = client
    end

    def feed(params = {})
      Twikey::Feed.new do |options|
        @client.get('/invoice', params)["Invoices"]
      end
    end

    def create_invoice(params)
      @client.post('/invoice', params)
    end

    def pdf(invoice_id)
      @client.get_binary("/invoice/#{invoice_id}/pdf")
    end
  end

  class TransactionService
    def initialize(client)
      @client = client
    end

    def get(params = {})
      @client.get('/transaction', params)
    end

    def feed(params = {})
      Twikey::Feed.new do |options|
        @client.get('/transaction', params)["Entries"]
      end
    end
  end

  class PaylinkService
    def initialize(client)
      @client = client
    end

    def new(params = {})
      @client.post('/payment/link', params, true)
    end

    def feed(params = {})
      Twikey::Feed.new do |options|
        @client.get('/payment/link/feed', params)["Links"]
      end
    end
  end
end
