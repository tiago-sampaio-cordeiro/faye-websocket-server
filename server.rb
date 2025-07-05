require 'faye/websocket'
require 'eventmachine'
require 'puma'
require 'rack'
require 'json'

# Faye::WebSocket.load_adapter('puma')

App = lambda do |env|
  if Faye::WebSocket.websocket?(env)
    ws = Faye::WebSocket.new(env)

    # Log para conexão aberta
    ws.on :open do |_event|
      client_ip = env['REMOTE_ADDR'] || 'Desconhecido'
      puts "Cliente conectado: #{client_ip}"
    end

    # Log para mensagens recebidas
    ws.on :message do |event|
      begin
        # Converte a mensagem recebida de JSON para um hash
        message = JSON.parse(event.data)
        puts "Mensagem recebida como JSON:"
        puts JSON.pretty_generate(message)

        if message['cmd'] == 'reg'
          puts "Registro recebido para o dispositivo: #{message['sn']}"

          response = {
            ret: 'reg',
            result: true,
            cloudtime: Time.now,
            nosenduser: true
          }

          ws.send(response.to_json)
          puts "Resposta enviada ao dispositivo:"
          puts JSON.pretty_generate(response)

        elsif message['cmd'] == 'sendlog'
          puts "Logs recebidos do dispositivo: #{message['sn']}"
          puts "Total de logs: #{message['count']}"

          # Iterar pelos registros de log recebidos
          if message['record']
            message['record'].each_with_index do |log, index|
              puts "Log #{index + 1}:"
              puts JSON.pretty_generate(log)
            end
          else
            puts "Nenhum registro de log encontrado."
          end

          response = {
            ret: 'sendlog',
            result: true,
            count: message['count'],
            logindex: message['logindex'],
            cloudtime: Time.now.utc.iso8601,
            access: 1,
            message: 'Logs recebidos com sucesso'
          }

          ws.send(response.to_json)
          puts "Resposta enviada ao dispositivo:"
          puts JSON.pretty_generate(response)

        else
          puts "Comando não reconhecido: #{message['cmd']}"
          ws.send({ ret: 'error', reason: 'Unknown command' }.to_json)
        end

      rescue JSON::ParserError => e
        puts "Erro ao processar a mensagem recebida (JSON inválido): #{e.message}"

        # Resposta de erro para JSON inválido
        error_response = {
          ret: 'error',
          reason: 'Invalid JSON format'
        }
        ws.send(error_response.to_json)

      rescue => e
        puts "Erro inesperado: #{e.message}"
        ws.send({ ret: 'error', reason: 'Internal server error' }.to_json)
      end
    end

    # Log para desconexão
    ws.on :close do |event|
      puts "Cliente desconectado: Code=#{event.code}, Reason=#{event.reason}"
    end

    # Log para erros
    ws.on :error do |event|
      puts "Erro na conexão: #{event.message}"
    end

    # Retorna a resposta WebSocket
    ws.rack_response
  else
    # Log para requisições HTTP normais
    puts "Requisição HTTP recebida: #{env['PATH_INFO']}"
    [200, { 'Content-Type' => 'text/plain' }, ['Hello']]
  end
end

