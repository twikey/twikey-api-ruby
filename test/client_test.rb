require 'minitest/autorun'
require 'net/http'
require 'uri'
require 'json'
require 'faker'

require_relative '../lib/twikey-api-ruby'

class TestTwikeyClient < Minitest::Test

  def setup
    skip "No API key configured" unless ENV["TWIKEY_API_KEY"]

    @client ||= Twikey::Client.new(
      api_key: ENV["TWIKEY_API_KEY"],
      url: ENV["TWIKEY_API_URL"] || "https://api.beta.twikey.com/creditor"
    )

    @ct = ENV["CT"]
    @mndt_number = ENV["MNDTNUMBER"]
    skip "CT not defined" unless @ct
    skip "MNDTNUMBER not defined" unless @mndt_number

    @customer_number = Faker::Crypto.sha1
  end

  def new_test_client
    Twikey::Client.new(ENV["TWIKEY_API_KEY"] || "your_api_key")
  end

  def test_verify_webhook
    client = Twikey::Client.new(api_key: "1234", url: "http://doesntmatter")
    equals = client.verify_webhook("55261CBC12BF62000DE1371412EF78C874DBC46F513B078FB9FF8643B2FD4FC2", "abc=123&name=abc")

    assert equals, "Error verifying webhook"
    assert_raises Twikey::Error, "Error verifying webhook" do
      client.verify_webhook("notthesignature", "abc=123&name=abc")
    end
  end

  def test_client_ping
    assert @client
    assert @client.ping
  end

  def test_mandate_invite
    invite = @client.mandates.invite({
        "ct": @ct,
        "email":  Faker::Internet.email,
        "firstname":  Faker::Name.first_name,
        "lastname": Faker::Name.last_name,
        "l": "en",
        "address": "Abby road",
        "city": "Liverpool",
        "zip": "1526",
        "country": "BE",
        # "mobile": "",
        # "iban": "",
        # "bic": "",
        # "mandateNumber": "",
        # "contractNumber": "",
      })
    assert invite
    assert invite["mndtId"]
    assert invite["url"]
  end

  def test_mandate_sign
    mandate = @client.mandates.sign({
        "method": "paper",
        "ct": @ct,
        "email":  Faker::Internet.email,
        "firstname":  Faker::Name.first_name,
        "lastname": Faker::Name.last_name,
        "l": "en",
        "address": "Abby road",
        "city": "Liverpool",
        "zip": "1526",
        "country": "BE",
        # "mobile": "",
        # "iban": "",
        # "bic": "",
        # "mandateNumber": "",
        # "contractNumber": "",
      })
    assert mandate["MndtId"]
    assert mandate["Pdf"]
  end

  def test_mandate_feed
    @client.mandates.feed.lazy.each do |mandate|
      assert mandate
    end
  end

  def test_invoice_feed
    @client.invoices.feed.lazy.each do |invoice|
      assert invoice
    end
  end

  def test_invoice_pdf
    skip "Invoice number not defined" unless ENV["INVOICE_NUMBER"]

    pdf_content = @client.invoices.pdf(ENV["INVOICE_NUMBER"])
    assert pdf_content
    assert pdf_content.start_with?("%PDF"), "Expected PDF content to start with %PDF"
  end

  def test_tx_feed
    @client.transactions.feed.lazy.each do |tx|
      assert tx
    end
  end

  def test_paylinks_feed
    @client.paylinks.feed.lazy.each do |tx|
      assert tx
    end
  end
end