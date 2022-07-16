require "opentelemetry/sdk"
require "opentelemetry/exporter/jaeger"
require "opentelemetry/instrumentation/sinatra"
require "opentelemetry/instrumentation/mysql2"
require "sinatra/base"
require "mysql2"
require "json"
require_relative "../patches/opentelemetry-ruby-contrib/support_stmt"

OpenTelemetry::SDK.configure do |c|
  c.use "OpenTelemetry::Instrumentation::Sinatra"
  c.use "OpenTelemetry::Instrumentation::Mysql2",
        { db_statement: :obfuscate, peer_service: "mysql" }
  c.add_span_processor(
    OpenTelemetry::SDK::Trace::Export::BatchSpanProcessor.new(
      OpenTelemetry::Exporter::Jaeger::AgentExporter.new(
        host: "kubernetes.docker.internal",
        port: 6831
      )
    )
  )

  c.service_name = "app1"
  c.service_version = "0.1.0"
end

class App < Sinatra::Base
  configure :development do
    require "sinatra/reloader"
    register Sinatra::Reloader
  end

  class MySQLConnectionEnv
    def initialize
      @host = get_env("MYSQL_HOST", "127.0.0.1")
      @port = get_env("MYSQL_PORT", "3333")
      @user = get_env("MYSQL_USER", "user")
      @db_name = get_env("MYSQL_DBNAME", "app")
      @password = get_env("MYSQL_PASS", "password")
    end

    def connect_db
      Mysql2::Client.new(
        host: @host,
        port: @port,
        username: @user,
        database: @db_name,
        password: @password,
        charset: "utf8mb4",
        database_timezone: :local,
        cast_booleans: true,
        symbolize_keys: true,
        reconnect: true
      )
    end

    private

    def get_env(key, default)
      val = ENV.fetch(key, "")
      return val unless val.empty?
      default
    end
  end

  helpers do
    def json_params
      @json_params ||=
        JSON.parse(request.body.tap(&:rewind).read, symbolize_names: true)
    end

    def db
      Thread.current[:db] ||= MySQLConnectionEnv.new.connect_db
    end

    def get_top_fruits
      db.query(
        "SELECT name, value FROM fruits ORDER BY value DESC LIMIT 5",
        as: :hash
      ).to_a
    end

    def search_fruits(name)
      stmt =
        db
          .prepare("SELECT * FROM fruits WHERE name = ?")
          .execute(name, as: :hash)
          .to_a
    end
  end

  get "/hello" do
    { hello: "world" }.to_json
  end

  get "/" do
    data = get_top_fruits
    chart = {
      chart: {
        type: "pie",
        title: "Top 5 fruits",
        data: data,
        container: "container"
      }
    }
    chart.to_json
  end

  get "/search/:query" do
    result = search_fruits(params["query"])
    result.to_json
  end
end
