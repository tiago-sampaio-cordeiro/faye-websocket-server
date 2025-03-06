# ultima versao do ruby
FROM ruby:latest

#atualizando pacotes e instalando bibliotecas e dependencias
RUN apt update && \
    apt install -y build-essential libpq-dev

#definindo o diretorio de trabalho
WORKDIR /usr/src/app

# copia o arquivo Gemfile para dentro do container
COPY Gemfile ./

#instala gems
RUN bundle install

COPY . .

# Cria um usuário para evitar rodar como root
RUN useradd -m appuser && chown -R appuser /usr/src/app
USER appuser

# Deixa a porta 4567 exposta
EXPOSE 9292

# Comando para iniciar o servidor
CMD ["thin", "start", "--rackup", "config.ru", "--address", "0.0.0.0", "--port", "9292"]





