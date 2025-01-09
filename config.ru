require 'faye/websocket'
require 'eventmachine'
require 'thin'
require 'json'

Faye::WebSocket.load_adapter('thin')

App = lambda do |env|
  if Faye::WebSocket.websocket?(env)
    ws = Faye::WebSocket.new(env)

    # Log para conexão aberta
    ws.on :open do |event|
      puts "Client connected: #{env['REMOTE_ADDR']}"
    end

    # Log para mensagens recebidas
    ws.on(:message) do |event|
      begin
        # Converte a mensagem recebida de JSON para um hash
        message = JSON.parse(event.data)
        puts "Mensagem recebida como JSON: #{message}"

        if message['cmd'] == 'reg'
          puts "Registro recebido para o dispositivo: #{message['sn']}"

          response = {
            ret: 'reg',
            result: true,
            cloudtime: Time.now.utc.iso8601,
            nosenduser: true
          }

          ws.send("PONTO:" + response.to_json)
          puts "Resposta enviada ao dispositivo: #{response}"
        elsif message['cmd'] == 'sendlog'
          puts "Logs recebidos do dispositivo: #{message['sn']}"
          puts "Total de logs: #{message['count']}"

          # Iterar pelos registros de log recebidos
          message['record'].each_with_index do |log, index|
            puts "Log #{index + 1}: #{log}"
          end

          response = {
            ret: "sendlog",
            result: true,
            count: message[:count],
            logindex: message[:logindex],
            cloudtime: Time.now.utc.iso8601,
            access: 1,
            message: message[:message]         }
          ws.send("PONTO:" + response.to_json)
          puts "Resposta enviada ao dispositivo: #{response}"
        else
          puts "Comando não reconhecido: #{message['cmd']}"
        end
      rescue JSON::ParserError => e
        puts "Erro ao processar a mensagem recebida: #{e.message}"

        # Resposta de erro para JSON inválido
        error_response = {
          ret: 'error',
          reason: 'Invalid JSON format'
        }
        ws.send(error_response.to_json)
      rescue => e
        puts "Erro inesperado: #{e.message}"
      end
    end

    # Log para desconexão
    ws.on :close do |event|
      puts "Client disconnected: Code=#{event.code}, Reason=#{event.reason}"
      ws = nil
    end

    ws.on :error do |event|
      puts "Erro na conexão: #{event.message}"
    end


    # Retorna a resposta WebSocket
    ws.rack_response
  else
    # Log para requisições HTTP normais
    puts "HTTP request received: #{env['PATH_INFO']}"
    [200, { 'Content-Type' => 'text/plain' }, ['Hello']]
  end
end

run App