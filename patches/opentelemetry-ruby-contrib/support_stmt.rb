require "opentelemetry/instrumentation/mysql2/patches/client"

module OpenTelemetry
  module Instrumentation
    module Mysql2
      module Patches
        module Statement
          def memo_query(sql, client)
            @query = sql
            @client = client
          end

          def execute(*args, **kwargs)
            @client.trace(@query) { super(*args, **kwargs) }
          end
        end

        module Client
          def query(sql, options = {})
            trace(sql) { super(sql, options) }
          end

          def prepare(sql)
            stmt = super(sql)
            stmt.memo_query(sql, self)
            stmt
          end

          def trace(statement, &block)
            attributes = client_attributes
            case config[:db_statement]
            when :include
              attributes["db.statement"] = statement
            when :obfuscate
              attributes["db.statement"] = obfuscate_sql(statement)
            end
            tracer.in_span(
              database_span_name(statement),
              attributes:
                attributes.merge!(
                  OpenTelemetry::Instrumentation::Mysql2.attributes
                ),
              kind: :client
            ) { block.call }
          end
        end
      end

      class Instrumentation < OpenTelemetry::Instrumentation::Base
        private

        def require_dependencies
          # NOP
        end

        def patch_client
          ::Mysql2::Client.prepend(Patches::Client)
          ::Mysql2::Statement.prepend(Patches::Statement)
        end
      end
    end
  end
end
