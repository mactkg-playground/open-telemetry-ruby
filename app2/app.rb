require "opentelemetry/sdk"
require "opentelemetry/exporter/jaeger"
require "opentelemetry/instrumentation/sinatra"
require "opentelemetry/instrumentation/faraday"
require "sinatra/base"
require "json"
require "faraday"
require "faraday/net_http"
require_relative "../patches/opentelemetry-ruby-contrib/support_stmt"

Faraday.default_adapter = :net_http
OpenTelemetry::SDK.configure do |c|
  c.use "OpenTelemetry::Instrumentation::Sinatra"
  c.use "OpenTelemetry::Instrumentation::Faraday"
  c.add_span_processor(
    OpenTelemetry::SDK::Trace::Export::BatchSpanProcessor.new(
      OpenTelemetry::Exporter::Jaeger::AgentExporter.new(
        host: "kubernetes.docker.internal",
        port: 6831
      )
    )
  )

  c.service_name = "app2"
  c.service_version = "0.1.0"
end

class App < Sinatra::Base
  configure :development do
    require "sinatra/reloader"
    register Sinatra::Reloader
  end

  get "/ranking" do
    response = Faraday.get("http://localhost:9292/")
    response.body
  end

  get "/search/:message" do
    response = Faraday.get("http://localhost:9292/search/#{params[:message]}")
    response.body
  end

  get "/echo/:msg" do
    { message: params[:msg].split().shuffle.join }.to_json
  end

  get "/" do
    sleep 1
    { time: Time.now }.to_json
  end
end
