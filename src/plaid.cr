require "http/client"
require "json"

module Plaid
  @@mode = :sandbox
  @@secret = ""
  @@client_id = ""

  PLAID_VERSION = "2018-05-22"
  VALID_MODES = [:sandbox, :development, :production]

  private def self.generate_headers
    headers = HTTP::Headers.new
    headers["Content-Type"] = "application/json"
    headers["Plaid-Version"] = PLAID_VERSION
    headers
  end

  private def self.endpoint(path)
    "https://#{@@mode}.plaid.com#{path}"
  end

  def self.mode=(val : Symbol)
    raise "mode must be one of #{VALID_MODES}" unless VALID_MODES.includes? val
    @@mode = val
  end

  def self.secret=(secret : String)
    @@secret = secret
  end

  def self.client_id=(client_id : String)
    @@client_id = client_id
  end

  def self.exchange_token(public_token : String)
    url = endpoint "/item/public_token/exchange"
    form = JSON.build do |json|
      json.object do
        json.field "client_id", @@client_id
        json.field "public_token", public_token
        json.field "secret", @@secret
      end
    end
    response = HTTP::Client.post url, generate_headers, form
    JSON.parse response.body
  end

  def self.identity(access_token : String)
    url = endpoint "/identity/get"
    form = JSON.build do |json|
      json.object do
        json.field "client_id", @@client_id
        json.field "access_token", access_token
        json.field "secret", @@secret
      end
    end
    response = HTTP::Client.post url, generate_headers, form
    JSON.parse response.body
  end

  def self.balance(access_token : String, account_ids : Array(String))
    url = endpoint "/accounts/balance/get"
    form = JSON.build do |json|
      json.object do
        json.field "client_id", @@client_id
        json.field "access_token", access_token
        json.field "secret", @@secret
        json.field "options" do
          json.object do
            json.field "account_ids", account_ids
          end
        end
      end
    end
    response = HTTP::Client.post url, generate_headers, form
    JSON.parse response.body
  end

  def self.transactions(access_token : String, start_date : Time | String | Nil = nil, end_date : String | Nil = nil, count : Int32 | Nil = 500, offset : Int32 | Nil = 0)
    url = endpoint "/transactions/get"
    start_date = start_date.to_s("%F") if start_date.is_a? Time
    end_date = end_date.to_s("%F") if end_date.is_a? Time
    start_date ||= (Time.now - 500.years).to_s("%F")
    end_date ||= (Time.now + 1.day).to_s("%F")
    form = JSON.build do |json|
      json.object do
        json.field "client_id", @@client_id
        json.field "secret", @@secret
        json.field "access_token", access_token
        json.field "start_date", start_date
        json.field "end_date", end_date
        json.field "options" do
          json.object do
            json.field "count", count
            json.field "offset", offset
          end
        end
      end
    end
    response = HTTP::Client.post url, generate_headers, form
    JSON.parse response.body
  end

  def self.all_transactions(access_token : String)
    cursor = 0
    oldest_date = ""
    saved_transactions = [] of JSON::Any
    accounts = nil
    loop do
      data = transactions(access_token, nil, nil, 500, cursor)
      accounts = data["accounts"].as_a if first_dataset.nil?
      data = data["transactions"].as_a
      data.each do |transaction|
        saved_transactions.push transaction
      end
      cursor += data.size
      break if data.empty?
      oldest_date = data.last["date"]
    end
    return saved_transactions, oldest_date, accounts.not_nil!
  end
end
