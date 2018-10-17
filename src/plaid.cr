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

  private def self.standard_endpoint(path : String, access_token : String)
    url = endpoint path
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
    standard_endpoint "/identity/get", access_token
  end

  def self.income(access_token : String)
    standard_endpoint "/income/get", access_token
  end
  
  def accounts(access_token : String)
    standard_endpoint "/accounts/get", access_token
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

  def create_asset_report(access_tokens : Array(String), days_requested : Int, options : JSON::Any)
    url = endpoint "/asset_report/create"
    form = JSON.build do |json|
      json.object do
        json.field "client_id", @@client_id
        json.field "access_tokens", access_tokens
        json.field "days_requested", days_requested
        json.field "secret", @@secret
        json.field "options", options
      end
    end
    response = HTTP::Client.post url, generate_headers, form
    JSON.parse response.body
  end

  def refresh_asset_report(asset_report_token : String, days_requested : Int | Nil = nil, options : JSON::Any | Nil = nil)
    url = endpoint "/asset_report/refresh"
    form = JSON.build do |json|
      json.object do
        json.field "client_id", @@client_id
        json.field "asset_report_token", asset_report_token
        json.field "days_requested", days_requested if days_requested != nil
        json.field "secret", @@secret
        json.field "options", options if options != nil
      end
    end
    response = HTTP::Client.post url, generate_headers, form
    JSON.parse response.body
  end

  def filter_asset_report(asset_report_token : String, account_ids_to_exclude : Array(String))
    url = endpoint "/asset_report/filter"
    form = JSON.build do |json|
      json.object do
        json.field "client_id", @@client_id
        json.field "secret", @@secret
        json.field "asset_report_token", asset_report_token
        json.field "account_ids_to_exclude", account_ids_to_exclude
      end
    end
    response = HTTP::Client.post url, generate_headers, form
    JSON.parse response.body
  end

  def get_asset_report(asset_report_token : String)
    url = endpoint "/asset_report/get"
    form = JSON.build do |json|
      json.field "client_id", @@client_id
      json.field "secret", @@secret
      json.field "asset_report_token", asset_report_token
    end
    response = HTTP::Client.post url, generate_headers, form
    JSON.parse response.body
  end

  def get_asset_report_pdf(asset_report_token : String)
    url = endpoint "/asset_report/pdf/get"
    form = JSON.build do |json|
      json.field "client_id", @@client_id
      json.field "secret", @@secret
      json.field "asset_report_token", asset_report_token
    end
    response = HTTP::Client.post url, generate_headers, form
    response.body
  end

  def create_asset_report_audit_copy(asset_report_token : String, auditor_id : String)
    url = endpoint "/asset_report/audit_copy/create"
    form = JSON.build do |json|
      json.field "client_id", @@client_id
      json.field "secret", @@secret
      json.field "asset_report_token", asset_report_token
      json.field "auditor_id", auditor_id
    end
    response = HTTP::Client.post url, generate_headers, form
    JSON.parse response.body
  end

  def remove_asset_report(asset_report_token : String)
    url = endpoint "/asset_report/remove"
    form = JSON.build do |json|
      json.field "client_id", @@client_id
      json.field "secret", @@secret
      json.field "asset_report_token", asset_report_token
    end
    response = HTTP::Client.post url, generate_headers, form
    JSON.parse response.body
  end

  def remove_asset_report_audit_copy(audit_copy_token : String)
    url = endpoint "/asset_report/audit_copy/create"
    form = JSON.build do |json|
      json.field "client_id", @@client_id
      json.field "secret", @@secret
      json.field "audit_copy_token", audit_copy_token
    end
    response = HTTP::Client.post url, generate_headers, form
    JSON.parse response.body
  end
end
